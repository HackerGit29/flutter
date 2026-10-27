# Architecture — deux boîtiers, broker MQTT et base de données

Comment **deux boîtiers ESP32** (box #1 et box #2) communiquent et se
synchronisent avec la base de données Supabase **via le broker MQTT EMQX
Cloud Serverless** (`r1aa3902.ala.eu-central-1.emqxsl.com:8883`, TLS).

## Vue d'ensemble

```mermaid
flowchart TB
  subgraph Boxes["Boîtiers ESP32 (client MQTT 5)"]
    direction LR
    B1["Boîtier #1<br/>uid: box-aaa<br/>3 relais + DHT22 + ACS712"]
    B2["Boîtier #2<br/>uid: box-bbb<br/>3 relais + DHT22 + ACS712"]
  end

  subgraph Broker["Broker MQTT — EMQX Cloud Serverless (Europe)"]
    direction TB
    T1["aricie/v1/boxes/+/telemetry"]
    T2["aricie/v1/boxes/+/status"]
    T3["aricie/v1/boxes/+/relays/+/ack"]
    T4["aricie/v1/boxes/+/relays/+/cmd"]
  end

  subgraph Workers["Relais de commandes (actifs/actifs, claim atomique)"]
    direction TB
    WCF["Worker Cloudflare<br/>aricie-mqtt5-worker (container en veille 10 min)"]
    WLOC["Relais local WSL/cloudflared<br/>mêmes credentials, même code"]
  end

  subgraph Supa["Supabase"]
    direction TB
    DB[("PostgreSQL<br/>appliances • boxes<br/>device_commands • realtime_power • energy_data")]
    RT["Realtime (broadcast)"]
    EF["Edge Function<br/>agent-orchestrator"]
  end

  App["Application Flutter<br/>(abonnée realtime + contrôle)"]

  B1 -->|"PUBLISH QoS 1<br/>télémétrie 2s + status + ACK"| Broker
  B2 -->|"PUBLISH QoS 1<br/>télémétrie 2s + status + ACK"| Broker
  Broker -->|"telemetry / ack"| WCF
  Broker -->|"telemetry / ack"| WLOC
  Broker -->|"cmd"| B1
  Broker -->|"cmd"| B2

  WCF <-->|"claim pending → publish cmd<br/>+ upsert realtime_power / appliances"| DB
  WLOC <-->|"idem (claim atomique = pas de double traitement)"| DB

  DB --> RT
  RT --> App
  App -->|"INSERT device_commands<br/>(via Edge Function / agent)"| DB
  EF --> DB
```

## Cycle de vie du worker Cloudflare (coût)

Le container **ne tourne pas en permanence** : après **10 min sans requête**,
il passe en veille (`LIVE INSTANCES → 0`, plus de facturation) et se réveille
au prochain appel HTTP. Pendant la veille, le **relais local** assure la
continuité ; le claim atomique sur `device_commands` empêche tout double
traitement.

```mermaid
stateDiagram-v2
  [*] --> Dormant : veille, 0 instance facturée
  Dormant --> Actif : requête HTTP (curl /health, wake-on-request)
  Actif --> Dormant : 10 min sans requête → enforceSleep stop() SIGTERM, SIGKILL secours après 30 s
```

## Séquence : commande « Éteins le chauffe-eau » (box #1)

```mermaid
sequenceDiagram
  participant U as Utilisateur (App Flutter)
  participant EF as Edge Function<br/>agent-orchestrator
  participant DB as Supabase (device_commands)
  participant W as Worker MQTT (Cloudflare ou local)
  participant Brk as Broker EMQX
  participant B1 as Boîtier #1

  U->>EF: message « Éteins le chauffe-eau » (JWT)
  EF->>EF: Policy Engine (ownership + rate limit + confirmation si high)
  EF->>DB: INSERT device_commands (status = pending, box_uid)
  EF-->>U: SSE tool_result (queued)

  W->>DB: claim atomique (pending → processing)
  W->>Brk: PUBLISH aricie/v1/boxes/box-aaa/relays/1/cmd (QoS 1)
  Brk->>B1: commande
  B1->>B1: bascule le relais 1
  B1-->>Brk: PUBLISH .../relays/1/ack
  Brk-->>W: ACK
  W->>DB: UPDATE device_commands (status = sent)<br/>UPDATE appliances (is_on)
```

## Séquence : télémétrie des deux boîtiers → synchronisation BDD

```mermaid
sequenceDiagram
  participant B1 as Boîtier #1
  participant B2 as Boîtier #2
  participant Brk as Broker EMQX
  participant W as Worker MQTT
  participant DB as Supabase
  participant App as Application Flutter

  B1->>Brk: PUBLISH box-aaa/telemetry {power_w, kwh_total} (2s)
  B2->>Brk: PUBLISH box-bbb/telemetry {power_w, kwh_total} (2s)
  Brk-->>W: flux des deux boxes (souscription .../boxes/+/telemetry)
  W->>DB: UPSERT realtime_power (par appliance_id)
  W->>DB: UPDATE appliances.is_on / last_seen
  DB->>DB: energy-aggregator (cron) → energy_data (kwh/jour)
  DB-->>App: Realtime (realtime_power, device_commands)
  App-->>App: Dashboard + LiveConsumptionIndicator (box #1 et #2)
```

## Topics MQTT 5 (namespace `aricie/v1/boxes/{uid}/…`)

| Topic | Producteur | Consommateur | Rôle |
|-------|-----------|--------------|------|
| `…/telemetry` | Boîtier | Worker, App (abonnement) | puissance instantanée, énergie cumulée, DHT22 |
| `…/status` | Boîtier | Worker, App | heartbeat, version firmware, état WiFi |
| `…/relays/{i}/cmd` | Worker | Boîtier | commande relay (on/off) |
| `…/relays/{i}/ack` | Boîtier | Worker | accusé de réception (→ `device_commands.status = sent`) |

## Règles clés

- **L'app Flutter ne publie jamais sur MQTT** : toute commande passe par la
  file `device_commands` (BDD), relaie par le worker → broker.
- **Les deux workers (Cloudflare + local) sont actifs/actifs** : le claim
  atomique `UPDATE … WHERE status = 'pending' RETURNING` garantit qu'une
  commande n'est envoyée qu'une seule fois.
- **Chaque boîtier est identifié par `uid_hardware`** (table `boxes`), les
  appliances sont scopées par `box_id` et `user_id` (RLS).
- **La synchronisation BDD est unidirectionnelle montante** (télémétrie →
  `realtime_power` / `appliances`) et bidirectionnelle pour les commandes
  (BDD → MQTT → boîtier → ACK → BDD).

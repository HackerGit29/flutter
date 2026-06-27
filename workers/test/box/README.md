# Boîtier ESP32 Simulé (Python)

Simule le comportement d'un boîtier physique ESP32 pour tester et valider le workflow MQTT complet d'Aricie.

## Prérequis

```bash
pip install -r requirements.txt
```

## Usage

```bash
python box_esp32.py <boxUid> <flespi_token>
```

**Paramètres :**
- `boxUid` : Identifiant matériel du boîtier (ex: `ESP32-A1B2C3D4`, > 8 caractères)
- `flespi_token` : Token Flespi avec permission PUBLISH/SUBSCRIBE

**Exemple :**
```bash
python box_esp32.py ESP32-A1B2C3D4 ngpSuWWVPzhGAz2JDeLRdKkRFClEKJDUUp9GszFbxOms8LKdiPYzhfl2RbXNxHB2
```

## Comportement

| Action | Topic | Fréquence |
|--------|-------|-----------|
| Publie status | `aricie/v1/boxes/{boxUid}/status` | Au démarrage |
| Publie télémétrie | `aricie/v1/boxes/{boxUid}/telemetry` | Toutes les 5s |
| Souscrit commandes | `aricie/v1/boxes/{boxUid}/relays/+/cmd` | Permanent |
| Publie ACK | `aricie/v1/boxes/{boxUid}/relays/{idx}/ack` | Sur chaque commande |

### Payload télémétrie

```json
{
  "temperature": 22.5,
  "humidity": 45,
  "relays": [
    {"index": 1, "status": "on", "power_w": 150},
    {"index": 2, "status": "off", "power_w": 0},
    {"index": 3, "status": "on", "power_w": 800}
  ],
  "power_w": 950,
  "kwh_total_per_relay": {"1": 3.2, "2": 0, "3": 9.3},
  "relay_power_w": {"1": 150, "2": 0, "3": 800}
}
```

### Payload ACK

```json
{
  "command_id": "uuid-v4",
  "success": true,
  "message": "Relay 1 turned ON successfully"
}
```

## Workflow de test

1. Démarrer le simulateur : `python box_esp32.py ESP32-A1B2C3D4 <token>`
2. Créer un boîtier dans l'admin avec le même UID (`ESP32-A1B2C3D4`)
3. Assigner le boîtier à un utilisateur
4. Lancer l'app Flutter → le DashboardTab souscrit au bon topic
5. Toggle un appareil depuis l'app → commande MQTT → ACK reçu
6. Vérifier dans l'onglet "Commandes" de l'admin que le statut passe à `acknowledged`

## Arrêt

`Ctrl+C` → arrêt propre avec déconnexion MQTT.

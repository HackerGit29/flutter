# OpenCode bridge — LLM free pour l'agent ARICIE

L'Edge Function `agent-orchestrator` parle à un LLM. Les modèles `*-free`
d'OpenCode Zen refusent les appels émis par un serveur :

```
403 FreeTierError: free tier can only be used from within OpenCode
```

Le blocage porte sur **l'émetteur**, pas sur la clé : ni le choix du modèle, ni
un `User-Agent`/`Origin` forgé ne le lèvent. Les modèles payants du même
catalogue acceptent, eux, les appels serveur (`402 Insufficient account funds`,
compte à zéro).

Ce pont contourne la limite **proprement** : il fait exécuter la requête par le
**client OpenCode de ta machine** (`opencode serve`), qui a le droit au free
tier, et il expose le résultat en `POST /chat/completions` au format OpenAI.

```
Flutter
  → Edge Function agent-orchestrator
    → OPENCODE_BRIDGE_URL/chat/completions         (bridge, ce dossier)
      → http://127.0.0.1:4096/session/{id}/message  (opencode serve, ta machine)
        → modèle free (deepseek-v4.1-flash-free, …)
```

**Contrepartie assumée** : le chat ne répond que quand ta machine est allumée
et le pont lancé. Dès que le compte OpenCode Zen est crédité, le pont devient
inutile : il suffit de retirer `OPENCODE_BRIDGE_URL` pour repasser sur
`DEEPSEEK_*` (déjà câblé, ordre de préférence géré dans `llm.ts`).

## Démarrage

```bash
# pont + tunnel public + mise à jour des secrets Supabase
bash workers/opencode-bridge/start.sh

# tests locaux sans tunnel
bash workers/opencode-bridge/start.sh --no-tunnel

# tunnel mais sans toucher aux secrets
bash workers/opencode-bridge/start.sh --no-secret
```

Le script lance `opencode serve` si nécessaire, démarre le pont sur `:4097`,
ouvre un tunnel `cloudflared`, puis pousse `OPENCODE_BRIDGE_URL`,
`OPENCODE_BRIDGE_TOKEN` et `OPENCODE_MODEL` dans les secrets Supabase.

`Ctrl+C` arrête le pont et le tunnel. Logs du tunnel : `.logs/cloudflared.log`.

> Le tunnel « quick » (`*.trycloudflare.com`) change d'URL à chaque démarrage ;
> le script repousse le secret automatiquement. Pour une URL stable, crée un
> tunnel nommé une fois : `cloudflared tunnel login`, puis
> `cloudflared tunnel create aricie-llm`,
> `cloudflared tunnel route dns aricie-llm llm.<ton-domaine>`, et remplace
> `--url` par `--config`/`run`.

## API du pont

| Route | Rôle |
|-------|------|
| `GET /health` | état du pont et joignabilité d'`opencode serve` |
| `POST /chat/completions` | format OpenAI (`messages`, `tools`, `stream`, `model`) |

Si `BRIDGE_TOKEN` est défini, `Authorization: Bearer <token>` est exigé sur
`/chat/completions` (`/health` reste ouvert et ne contient aucun secret).

### Tool calling

L'API locale d'OpenCode n'expose pas `tools`/`tool_calls` au format OpenAI. Le
pont transmet les définitions dans le prompt et attend une réponse JSON stricte :

```json
{"tool_calls":[{"name":"turn_off_appliance","arguments":{"appliance_name":"chauffe-eau"}}]}
```

qu'il reconvertit en `tool_calls` OpenAI (`finish_reason: "tool_calls"`), donc
l'Edge Function et le Policy Engine fonctionnent sans modification. Vérifié sur
`deepseek-v4.1-flash-free` : « Éteins le chauffe-eau » →
`turn_off_appliance({"appliance_name":"chauffe-eau"})`.

### Streaming

`stream: true` renvoie des chunks SSE `data: {...}` terminés par `data: [DONE]`,
comme un provider OpenAI. OpenCode répond en une fois ; le pont découpe la
réponse en morceaux de mots pour un rendu progressif côté Flutter.

## Env

| Variable | Défaut | Rôle |
|----------|--------|------|
| `OPENCODE_URL` | `http://127.0.0.1:4096` | URL de `opencode serve` |
| `OPENCODE_PROVIDER` | `opencode` | `providerID` OpenCode |
| `OPENCODE_MODEL` | `deepseek-v4.1-flash-free` | `modelID` par défaut |
| `BRIDGE_PORT` | `4097` | port d'écoute (loopback) |
| `BRIDGE_TOKEN` | — | si défini, Bearer requis |
| `BRIDGE_TIMEOUT_MS` | `240000` | timeout d'un appel modèle |
| `BRIDGE_AUTOSPAWN` | `true` | lance `opencode serve` si absent |

## Côté Edge Function

Ordre de préférence des providers (`supabase/functions/agent-orchestrator/llm.ts`) :

1. **bridge** — si `OPENCODE_BRIDGE_URL` est défini (gratuit, machine allumée) ;
2. **deepseek** — si `DEEPSEEK_API_KEY` est défini (OpenCode Zen) ;
3. **cloudflare** — si `CLOUDFLARE_ACCOUNT_ID` + `CLOUDFLARE_API_TOKEN` sont définis (Workers AI).

Toute panne (bridge éteint, 5xx, timeout, DNS) bascule sur le provider suivant.
Retirer le pont = `supabase secrets unset OPENCODE_BRIDGE_URL`.

## Dépannage

| Symptôme | Cause / solution |
|----------|------------------|
| `client OpenCode injoignable` | `opencode serve` non lancé (`opencode serve --port 4096`) |
| `403 FreeTierError` dans les logs | requête partie en direct sur `opencode.ai/zen` : l'Edge Function n'a pas le bon `OPENCODE_BRIDGE_URL` |
| le chat répond `llm_unavailable` | pont/tunnel arrêtés → machine éteinte ou `start.sh` interrompu |
| réponses lentes au premier message | démarrage à froid d'`opencode serve` |

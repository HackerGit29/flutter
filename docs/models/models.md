# Data Models

DTOs and models for serialization.

## Active Contract Models
- `BoxTelemetry`: **Contrat unique app→boîtier** défini par l'app. Payload JSONB reçu sur `device/{box_uid}/telemetry` :
  ```json
  { "temperature": 22.5, "humidity": 45,
    "relays": [
      { "index": 1, "status": "on", "power_w": 150 },
      { "index": 2, "status": "off", "power_w": 0 },
      { "index": 3, "status": "on", "power_w": 800 }
    ]
  }
  ```
- `RelayState`: Sous-modèle de `BoxTelemetry` (index, isOn, powerW).
- `ChatMessage`: Structure for AI chatbot messages.
  - `text`, `isUser`, `timestamp`
  - `isStreaming`: Indique si le message est en cours de réception (SSE)
  - `actionType`: Type d'action en cours (`turn_on_appliance`, etc.)
  - `isError`: Indique si le message est une erreur

## Agent Streaming Models
- `AgentStreamEvent`: Événement SSE reçu par le client Flutter
  - `event`: Type d'événement (`token`, `tool_pending`, `tool_result`, `error`, `done`)
  - `data`: Payload JSON de l'événement

## Domain Entity Serialization
`Box`, `Appliance`, `SyncLog`, `AdminAction`, `User`, `Subscription`, `License`, `EnergyData` gèrent leur propre JSON via `fromJson`/`toJson` dans le domaine — pas de modèles séparés.

## Legacy (supprimés)
- `TemperatureModel`, `HumidityModel`, `EnergyDataModel` — remplacés par `BoxTelemetry`.
- `DeviceModel` — remplacé par `Box` + `Appliance`.

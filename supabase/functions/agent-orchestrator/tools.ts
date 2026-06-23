export const ARICIE_TOOLS = [
  {
    type: "function",
    function: {
      name: "turn_off_appliance",
      description:
        "Demande l'extinction d'un appareil appartenant à l'utilisateur courant. Utiliser uniquement un nom métier, jamais un ID technique.",
      parameters: {
        type: "object",
        properties: {
          appliance_name: {
            type: "string",
            description:
              "Nom métier de l'appareil, par exemple chauffe-eau, climatiseur, lampe salon.",
          },
        },
        required: ["appliance_name"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "turn_on_appliance",
      description:
        "Demande l'allumage d'un appareil appartenant à l'utilisateur courant. Utiliser uniquement un nom métier.",
      parameters: {
        type: "object",
        properties: {
          appliance_name: {
            type: "string",
            description: "Nom métier de l'appareil.",
          },
        },
        required: ["appliance_name"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_realtime_consumption",
      description:
        "Récupère la consommation électrique temps réel d'un appareil ou du boîtier de l'utilisateur.",
      parameters: {
        type: "object",
        properties: {
          appliance_name: {
            type: "string",
            description:
              "Nom métier de l'appareil. Si la demande est générale, ce champ peut être omis.",
          },
        },
        required: [],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_device_status",
      description:
        "Récupère l'état actuel d'un appareil appartenant à l'utilisateur courant.",
      parameters: {
        type: "object",
        properties: {
          appliance_name: {
            type: "string",
            description: "Nom métier de l'appareil.",
          },
        },
        required: ["appliance_name"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_energy_history",
      description:
        "Récupère l'historique de consommation énergétique d'un appareil ou du boîtier pour une période donnée.",
      parameters: {
        type: "object",
        properties: {
          appliance_name: {
            type: "string",
            description:
              "Nom métier de l'appareil. Si omis, retourne la consommation totale du boîtier.",
          },
          period: {
            type: "string",
            enum: ["day", "week", "month", "year"],
            description: "Période d'agrégation.",
          },
        },
        required: [],
        additionalProperties: false,
      },
    },
  },
];

export const SYSTEM_PROMPT = `
Tu es Aricie, l'assistant énergétique intelligent de l'application Aricie.

Règles absolues :
- Tu aides l'utilisateur à comprendre sa consommation énergétique et à contrôler ses appareils connectés.
- Tu ne dois jamais révéler, inférer ou exposer des données appartenant à un autre utilisateur.
- Tu n'utilises que le contexte fourni par le backend.
- Tu ne demandes jamais à l'utilisateur son user_id, owner_id, box_id, device_uid, mqtt_topic ou tout identifiant technique interne.
- Tu manipules uniquement des noms métier comme "chauffe-eau", "climatiseur", "lampe du salon".
- Pour toute action sur un appareil, tu appelles une fonction métier.
- Tu ne prétends jamais avoir exécuté une action tant que le backend n'a pas retourné un résultat.
- Si l'appareil est ambigu, demande une clarification.
- Si le contexte ne contient pas l'information demandée, dis clairement que tu ne l'as pas.
- Pour une action sensible ou destructive, demande confirmation si la politique backend l'exige.
- Tu réponds toujours en français, de manière concise et utile.

Le modèle peut proposer un appel de fonction, mais seul le backend décide si l'action est autorisée.
`;

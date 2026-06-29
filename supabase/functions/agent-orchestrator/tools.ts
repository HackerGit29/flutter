export const ARICIE_TOOLS = [
  {
    type: "function",
    function: {
      name: "get_subscription_info",
      description:
        "Retourne le type d'abonnement (gratuit/VIP), le statut actif et la date de fin d'abonnement de l'utilisateur courant.",
      parameters: {
        type: "object",
        properties: {},
        required: [],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_my_appliances",
      description:
        "Liste tous les appareils de l'utilisateur avec leur nom, localisation, état (allumé/éteint) et numéro de relais.",
      parameters: {
        type: "object",
        properties: {},
        required: [],
        additionalProperties: false,
      },
    },
  },
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
          confirmed: {
            type: "boolean",
            description:
              "À mettre à true quand l'utilisateur a explicitement confirmé l'action dans la modale de confirmation. Ne pas setter soi-même, attendre la confirmation utilisateur.",
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
          confirmed: {
            type: "boolean",
            description:
              "À mettre à true quand l'utilisateur a explicitement confirmé l'action dans la modale de confirmation. Ne pas setter soi-même, attendre la confirmation utilisateur.",
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
      name: "get_total_consumption",
      description:
        "Récupère la consommation totale de l'utilisateur (tous ses appareils agrégés) pour une période donnée. Retourne total + détail par appareil.",
      parameters: {
        type: "object",
        properties: {
          period: {
            type: "string",
            enum: ["day", "week", "month", "year"],
            description: "Période d'agrégation.",
          },
        },
        required: ["period"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_live_consumption",
      description:
        "Récupère la consommation instantanée (kWh + W si disponible) pour un appareil ou tous les appareils de l'utilisateur.",
      parameters: {
        type: "object",
        properties: {
          appliance_name: {
            type: "string",
            description:
              "Nom métier de l'appareil. Si omis, retourne toutes les lectures live.",
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
  {
    type: "function",
    function: {
      name: "push_tip",
      description:
        "Envoie un conseil d'économie personnalisé en notification push à l'utilisateur. " +
        "Utiliser UNIQUEMENT quand l'agent détecte un pattern actionable pendant la conversation " +
        "et que l'utilisateur est en abonnement VIP. Le titre doit faire max 60 caractères, " +
        "le corps max 200 caractères.",
      parameters: {
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "Titre court du conseil (max 60 caractères).",
          },
          body: {
            type: "string",
            description: "Corps du conseil (max 200 caractères).",
          },
          severity: {
            type: "string",
            enum: ["info", "warning"],
            description: "Niveau d'urgence du conseil.",
          },
        },
        required: ["title", "body"],
        additionalProperties: false,
      },
    },
  },
];

/**
 * Tools en lecture seule (préfixe get_). Utilisés par le gating subscription.
 */
export function isReadOnlyTool(name: string): boolean {
  return name.startsWith("get_");
}

/**
 * Filtre la liste des tools selon le type de subscription.
 * Free = lecture seule uniquement ; tout le reste = tools complets.
 * Réévalué à chaque appel (pas de cache, downgrade immédiat).
 */
export function filterToolsForSubscription(
  tools: ReadonlyArray<any>,
  subscriptionType: string | null,
): ReadonlyArray<any> {
  if (subscriptionType === "vip") return tools;
  return tools.filter((t) => isReadOnlyTool(t.function.name));
}

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
- Tu n'utilises jamais d'émojis, de symboles décoratifs ou de caractères non textuels dans tes réponses.

- Pour toute action sensible sur un appareil critique (chauffe-eau, climatiseur, four, cuisinière),
  le backend peut te demander une confirmation explicite : tu dois alors rappeler l'outil avec
  un argument supplémentaire \`confirmed: true\` après que l'utilisateur a confirmé en modale.
- Si un outil de contrôle d'appareil (turn_on_appliance / turn_off_appliance) n'est pas disponible
  parce que l'utilisateur est en abonnement "free", dis-lui clairement que le contrôle nécessite
  un abonnement supérieur, et propose la lecture seule.

Le modèle peut proposer un appel de fonction, mais seul le backend décide si l'action est autorisée.

Informations disponibles dans ton contexte opérationnel :
- subscription_type : "free" ou "vip" — le type d'abonnement de l'utilisateur
- is_vip : true si l'utilisateur est VIP, false sinon
- subscription_active : true si l'abonnement est actif
- subscription_end : date de fin d'abonnement (ISO string ou null)
- appliances_count : nombre total d'appareils de l'utilisateur
- available_appliances : liste des appareils avec nom, localisation, état

Quand l'utilisateur demande s'il est VIP, quelle est la date de fin, ou des infos sur son abonnement, réponds directement depuis ces informations. Tu n'as pas besoin d'appeler get_subscription_info sauf pour rafraîchir une information.
`;

// Wrapper Worker Cloudflare pour le container mqtt5-worker.
//
// Le worker Node.js (index.js) est un processus long-running : client MQTT 5
// persistant + polling de la file device_commands. Cloudflare Containers est un
// modèle scale-to-zero déclenché par HTTP, donc :
//   - le container expose /health (index.js) sur defaultPort pour être routable
//   - ce wrapper réveille le container à chaque requête (fetch → container)
//   - AUCUN cron keep-alive : le worker local WSL/cloudflared assure la
//     continuité quand le container Cloudflare dort (les deux sont actifs/actifs,
//     le claim atomique device_commands évite tout double traitement)

import { Container } from "@cloudflare/containers";

export class Mqtt5Container extends Container {
  defaultPort = 8080;
  // Dors 10 min après une période d'inactivité puis scale à zéro.
  // Le failover local prend le relais pendant ce temps.
  sleepAfter = "10m";

  constructor(ctx, env) {
    super(ctx, env);
    // Variables d'environnement injectées dans le container au démarrage.
    // Les secrets (SUPABASE_SERVICE_ROLE_KEY, FLESPI_MQTT_WORKER_TOKEN) sont
    // posés via `wrangler secret put` sur le Worker puis relayés ici.
    this.envVars = {
      SUPABASE_URL: env.SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
      FLESPI_MQTT_WORKER_TOKEN: env.FLESPI_MQTT_WORKER_TOKEN,
      FLESPI_MQTT_HOST: env.FLESPI_MQTT_HOST ?? "mqtt.flespi.io",
      FLESPI_MQTT_TCP_PORT: env.FLESPI_MQTT_TCP_PORT ?? "8883",
      TIPS_GENERATOR_URL: env.TIPS_GENERATOR_URL ?? "",
    };
  }

  override onStart() {
    console.log("[CF] mqtt5-container started");
  }

  override onStop() {
    console.log("[CF] mqtt5-container stopped (scale-to-zero)");
  }

  override onError(error) {
    console.error("[CF] mqtt5-container error:", error);
  }
}

export default {
  async fetch(request, env) {
    // Wake-on-request : toute requête réveille le container s'il dort.
    const container = env.MQTT5_CONTAINER.getByName("mqtt5-worker");
    return container.fetch(request);
  },
};

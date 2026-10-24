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
//
// Diagnostic "The container is not running, consider calling start()" :
// ce message vient du binding natif getTcpPort().fetch (pas du SDK). On logue
// l'état DO + running natif avant proxy, et on force un start() + 2e essai si
// le proxy échoue (état possiblement périmé, cf. cloudflare/workerd#4362).

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

  onStart() {
    console.log("[CF] mqtt5-container started");
  }

  onStop() {
    console.log("[CF] mqtt5-container stopped (scale-to-zero)");
  }

  onError(error) {
    console.error("[CF] mqtt5-container error:", error);
  }
}

export default {
  async fetch(request, env) {
    const container = env.MQTT5_CONTAINER.getByName("mqtt5-worker");

    // Diagnostic : état perçu par le DO avant proxy.
    try {
      const running = container.container?.running;
      const doState = await container.state?.getState?.();
      console.log(`[CF] wake: native_running=${running} do_state=${JSON.stringify(doState)}`);
    } catch (e) {
      console.log("[CF] wake: diag unavailable:", e?.message ?? e);
    }

    // container.fetch → containerFetch() du SDK : startAndWaitForPorts si
    // nécessaire puis proxy TCP vers defaultPort. Un échec de démarrage arrive
    // en Response 500 (pas en throw) : on détecte ce corps pour réessayer avec
    // un start() explicite, contournant l'état interne périmé du DO.
    let res;
    try {
      res = await container.fetch(request);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error("[CF] proxy throw, retry avec start() explicite:", msg);
      res = null;
    }

    if (res && res.status === 500) {
      const body = await res.clone().text().catch(() => "");
      if (body.includes("Failed to start container")) {
        console.error("[CF] start refusé, retry start() + fetch:", body.slice(0, 300));
        try {
          await container.start();
          res = await container.fetch(request);
        } catch (err2) {
          const msg2 = err2 instanceof Error ? err2.message : String(err2);
          console.error("[CF] retry échec:", msg2);
          return new Response(`Failed to start container: ${msg2}`, { status: 500 });
        }
      }
    }
    return res;
  },
};

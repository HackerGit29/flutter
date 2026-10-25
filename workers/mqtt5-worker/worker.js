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

// Env relayé au container. Les secrets se lisent sur `env` (Worker secrets),
// le reste vient de `vars` (wrangler.jsonc).
function buildMqttEnvVars(env) {
  const username = env.MQTT_USERNAME ?? env.FLESPI_MQTT_WORKER_TOKEN;
  return {
    SUPABASE_URL: env.SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
    MQTT_HOST: env.MQTT_HOST ?? env.FLESPI_MQTT_HOST ?? "mqtt.flespi.io",
    MQTT_PORT: env.MQTT_PORT ?? env.FLESPI_MQTT_TCP_PORT ?? "8883",
    MQTT_USERNAME: username,
    MQTT_PASSWORD: env.MQTT_PASSWORD ?? username,
    TIPS_GENERATOR_URL: env.TIPS_GENERATOR_URL ?? "",
  };
}

// Délai de veille (doit refléter `sleepAfter`) et cadence du garde-fou.
const SLEEP_AFTER_S = 10 * 60;
const SLEEP_CHECK_S = 60;

export class Mqtt5Container extends Container {
  defaultPort = 8080;
  // Dors 10 min après une période d'inactivité puis scale à zéro.
  // Le failover local prend le relais pendant ce temps.
  sleepAfter = `${SLEEP_AFTER_S}s`;

  constructor(ctx, env) {
    super(ctx, env);
    // Activité observée par CE wrapper (le compteur interne du SDK peut rester
    // bloqué sur une requête annulée, cf. enforceSleep).
    this.lastActivityAt = Date.now();
    this.activeRequests = 0;
    // Variables d'environnement injectées dans le container au démarrage.
    // Les secrets (SUPABASE_SERVICE_ROLE_KEY, FLESPI_MQTT_WORKER_TOKEN) sont
    // posés via `wrangler secret put` sur le Worker puis relayés ici.
    // Credentials MQTT : noms génériques (MQTT_USERNAME / MQTT_PASSWORD) pour
    // EMQX Cloud Serverless, avec repli sur l'ancien token Flespi.
    this.envVars = buildMqttEnvVars(env);
    const presence = Object.entries(this.envVars)
      .map(([k, v]) => `${k}=${typeof v}`)
      .join(" ");
    console.log(`[CF] DO constructor envVars: ${presence}`);

    // Arment aussi ici : au (ré)création du DO, le container peut être déjà
    // lancé et onStart() ne sera alors plus rappelé → sans cette ligne, le
    // garde-fou ne repartirait qu'après un prochain stop/start.
    try {
      this.deleteSchedules("enforceSleep");
      this.schedule(SLEEP_CHECK_S, "enforceSleep", {})
        .catch((err) => console.error("[CF] arment veille:", err?.message ?? err));
    } catch (err) {
      console.error("[CF] arment veille impossible:", err?.message ?? err);
    }
  }

  // Trace l'activité réelle côté wrapper : c'est ce compteur qui déclenche la
  // veille, pas celui du SDK (dont `isActivityExpired()` ne se déclenche jamais
  // tant que `inflightRequests > 0`, y compris après une requête annulée).
  async fetch(request) {
    this.lastActivityAt = Date.now();
    this.activeRequests++;
    try {
      return await super.fetch(request);
    } finally {
      this.activeRequests = Math.max(0, this.activeRequests - 1);
      this.lastActivityAt = Date.now();
    }
  }

  async onStart() {
    console.log("[CF] mqtt5-container started");
    this.lastActivityAt = Date.now();
    // (Ré)armement du garde-fou de veille : on repart d'une tâche unique pour
    // ne pas cumuler les callbacks après un wake.
    try {
      this.deleteSchedules("enforceSleep");
      await this.schedule(SLEEP_CHECK_S, "enforceSleep", {});
    } catch (err) {
      console.error("[CF] arment veille impossible:", err?.message ?? err);
    }
  }

  // Garde-fou de veille : exécuté par la boucle d'alarms du SDK.
  // Arrête le container après SLEEP_AFTER_S sans requête → scale-to-zero →
  // plus de facturation instance tant qu'aucun client ne réveille le Worker.
  async enforceSleep() {
    if (!this.container?.running) return; // container déjà arrêté : on n'arme plus

    if (this.activeRequests > 0) {
      await this.schedule(30, "enforceSleep", {});
      return;
    }

    const idleMs = Date.now() - this.lastActivityAt;
    if (idleMs >= SLEEP_AFTER_S * 1000) {
      console.log(
        `[CF] veille forcée après ${Math.round(idleMs / 60000)} min sans requête`,
      );
      await this.stop();
      return;
    }
    const next = Math.max(
      15,
      Math.min(SLEEP_CHECK_S, Math.ceil((SLEEP_AFTER_S * 1000 - idleMs) / 1000)),
    );
    await this.schedule(next, "enforceSleep", {});
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
    const url = new URL(request.url);
    const container = env.MQTT5_CONTAINER.getByName("mqtt5-worker-v2");

    // Diagnostic Worker : longueurs (jamais valeurs) des variables vues par le
    // runtime du Worker — permet de distinguer "secret absent du Worker" de
    // "secret présent mais jamais relayé au container".
    if (url.pathname === "/_diag") {
      const lens = {};
      for (const k of [
        "SUPABASE_URL",
        "SUPABASE_SERVICE_ROLE_KEY",
        "MQTT_HOST",
        "MQTT_USERNAME",
        "MQTT_PASSWORD",
        "FLESPI_MQTT_WORKER_TOKEN",
        "FLESPI_MQTT_HOST",
      ]) {
        lens[k] = typeof env[k] === "string" ? env[k].length : String(env[k]);
      }
      return Response.json({ env_len: lens, env_keys: Object.keys(env).sort() });
    }

    // Route d'administration : force l'arrêt du container pour qu'au prochain
    // wake il reparte avec la config envVars courante (le start n'applique
    // env que quand il part de stopped).
    if (url.pathname === "/_stop") {
      await container.stop();
      await container.destroy();
      console.log("[CF] container stop+destroy demandé");
      return new Response("stopped", { status: 200 });
    }

    // Route d'administration : restart en passant envVars explicitement en
    // startOptions (contourne this.envVars éventuellement périmé d'un DO
    // instancié avant le posage des secrets).
    if (url.pathname === "/_restart") {
      await container.stop();
      await container.destroy();
      const envVars = buildMqttEnvVars(env);
      await container.start({ envVars });
      console.log("[CF] restart avec envVars explicites:", Object.keys(envVars).join(","));
      return new Response("restarted", { status: 200 });
    }

    // Diagnostic : état perçu par le DO avant proxy + présence (jamais la
    // valeur) des variables relayées au container.
    try {
      const running = container.container?.running;
      const presence = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "MQTT_USERNAME"]
        .map((k) => `${k}=${typeof env[k]}`)
        .join(" ");
      console.log(`[CF] wake: native_running=${running} env: ${presence}`);
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

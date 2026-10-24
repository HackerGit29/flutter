// Bootstrap de démarrage du container mqtt5-worker.
//
// Contexte : sur Cloudflare Containers, le container "crash" silencieusement
// (wrangler tail ne montre jamais le stdout du container — cf.
// cloudflare/containers#232). En local le même image fonctionne, donc on
// rend chaque étape observable :
//   1. serveur /health monté EN PREMIER (avant tout import applicatif) pour
//      que le port soit joignable même si l'app échoue
//   2. import dynamique de ./app.js (le code applicatif historique) — toute
//      exception d'import est capturée et exposée dans /health (fatal_errors)
//   3. handlers process-level (uncaughtException / unhandledRejection) qui
//      poussent dans fatalErrors au lieu de tuer le process immédiatement
//
// Le serveur /health répond donc dans TOUS les cas, ce qui laisse au
// diagnostic la possibilité de distinguer "container mort" (aucune réponse)
// de "app cassée mais container vivant" (status=degraded + fatal_errors).

import http from "node:http";

const WORKER_ID = `mqtt5-worker-${process.pid}`;
const startedAt = Date.now();
const fatalErrors = [];
const stats = { telemetryMessages: 0, acksProcessed: 0, commandsSent: 0 };

const REQUIRED_ENV = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "FLESPI_MQTT_WORKER_TOKEN",
];

// Exposé pour que /health reflète l'état MQTT de app.js une fois chargé.
const appState = { mqttConnected: false, loaded: false, loadMs: null };

const healthPort = Number(process.env.PORT ?? 8080);

const healthServer = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/") {
    const missing = REQUIRED_ENV.filter((k) => !process.env[k]);
    const status = fatalErrors.length || !appState.loaded ? "degraded" : "ok";
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        status,
        worker_id: WORKER_ID,
        bootstrap: true,
        app_loaded: appState.loaded,
        app_load_ms: appState.loadMs,
        mqtt_connected: appState.mqttConnected,
        uptime_s: Math.round((Date.now() - startedAt) / 1000),
        missing_env: missing,
        fatal_errors: fatalErrors,
        stats,
      }),
    );
  } else {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("not found");
  }
});

healthServer.listen(healthPort, () => {
  console.log(`[BOOT] Health server listening on :${healthPort}`);
});

// --- Garde-fous process : on reste vivant et observable ------------------
process.on("uncaughtException", (err) => {
  const msg = `uncaughtException: ${err?.stack ?? err}`;
  console.error("[BOOT]", msg);
  fatalErrors.push(msg.slice(0, 500));
});

process.on("unhandledRejection", (reason) => {
  const msg = `unhandledRejection: ${reason?.stack ?? reason}`;
  console.error("[BOOT]", msg);
  fatalErrors.push(msg.slice(0, 500));
});

// --- Chargement de l'app --------------------------------------------------
const t0 = Date.now();
try {
  const app = await import("./app.js");

  // app.js expose son état via globalThis (bricolage minimal, sans refonte).
  globalThis.__mqtt5App = {
    setMqttConnected: (v) => {
      appState.mqttConnected = v;
    },
    setStats: (s) => Object.assign(stats, s),
  };

  appState.loaded = true;
  appState.loadMs = Date.now() - t0;
  console.log(`[BOOT] app.js chargée en ${appState.loadMs}ms`);
} catch (err) {
  const msg = `app.js import failed: ${err?.stack ?? err}`;
  console.error("[BOOT]", msg);
  fatalErrors.push(msg.slice(0, 500));
}

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
// NB : ce global doit être posé AVANT l'import de app.js — app.js capture
// `globalThis.__mqtt5App` au chargement du module (sinon bootstrap=undefined
// et mqtt_connected ne remonte jamais dans /health).
const appState = {
  mqttConnected: false,
  loaded: false,
  loadMs: null,
  mqttState: "init",
  mqttLastError: null,
};

globalThis.__mqtt5App = {
  setMqttConnected: (v) => {
    appState.mqttConnected = v;
    appState.mqttState = v ? "connected" : "disconnected";
  },
  setMqttState: (s, err) => {
    appState.mqttState = s;
    if (err) appState.mqttLastError = String(err).slice(0, 300);
  },
  setStats: (s) => Object.assign(stats, s),
};

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
        mqtt_state: appState.mqttState,
        mqtt_last_error: appState.mqttLastError,
        uptime_s: Math.round((Date.now() - startedAt) / 1000),
        missing_env: missing,
        // Noms (jamais valeurs) des variables visibles par le process —
        // sert à vérifier que startConfig.env de la plateforme est appliqué.
        env_keys: Object.keys(process.env).sort(),
        fatal_errors: fatalErrors,
        stats,
      }),
    );
  } else if (req.url === "/diag/supabase") {
    // Vérifie que le container joint bien Supabase (REST + service role) :
    // sans ça le polling device_commands échoue silencieusement.
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "env manquant" }));
      return;
    }
    const t0 = Date.now();
    fetch(`${url}/rest/v1/device_commands?select=id&limit=1`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
    })
      .then(async (r) => ({
        http_status: r.status,
        body: (await r.text()).slice(0, 200),
        ms: Date.now() - t0,
      }))
      .catch((e) => ({ error: e?.message ?? String(e), ms: Date.now() - t0 }))
      .then((result) => {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(result));
      });
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
  await import("./app.js");
  appState.loaded = true;
  appState.loadMs = Date.now() - t0;
  console.log(`[BOOT] app.js chargée en ${appState.loadMs}ms`);
} catch (err) {
  const msg = `app.js import failed: ${err?.stack ?? err}`;
  console.error("[BOOT]", msg);
  fatalErrors.push(msg.slice(0, 500));
}

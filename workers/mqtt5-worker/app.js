import "dotenv/config";
import mqtt from "mqtt";
import { createClient } from "@supabase/supabase-js";

// Le serveur /health est monté par index.js (bootstrap) AVANT cet import :
// on ne crée plus de second serveur ici (EADDRINUSE) et on branche l'état
// MQTT sur le bootstrap via globalThis.__mqtt5App.
const WORKER_ID = `mqtt5-worker-${process.pid}`;
const stats = { telemetryMessages: 0, acksProcessed: 0, commandsSent: 0 };
const fatalErrors = [];
const REQUIRED_ENV = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
];

const bootstrap = globalThis.__mqtt5App;

// --- Init Supabase (non fatal : le health reste dispo) -------------------
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
  fatalErrors.push("SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY manquants");
  console.error("[FATAL] SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY absent");
}

const supabase = createClient(
  process.env.SUPABASE_URL ?? "http://invalid.supabase.local",
  process.env.SUPABASE_SERVICE_ROLE_KEY ?? "invalid",
);

// Broker MQTT 5 : config générique (MQTT_HOST / MQTT_PORT / MQTT_USERNAME /
// MQTT_PASSWORD) avec repli sur les noms historiques Flespi.
const mqttHost = process.env.MQTT_HOST ?? process.env.FLESPI_MQTT_HOST ?? "mqtt.flespi.io";
const mqttPort = Number(
  process.env.MQTT_PORT ?? process.env.FLESPI_MQTT_TCP_PORT ?? 8883,
);
// Legacy : le token Flespi sert de username ET de password.
const mqttToken = process.env.MQTT_USERNAME ?? process.env.FLESPI_MQTT_WORKER_TOKEN;
const mqttPassword = process.env.MQTT_PASSWORD ?? mqttToken;
const isFlespi = Boolean(process.env.FLESPI_MQTT_WORKER_TOKEN) &&
  !process.env.MQTT_USERNAME;

if (!mqttToken) {
  // Non fatal : sans credentials, pas de MQTT, mais le container reste vivant
  // et /health expose l'erreur pour diagnostiquer côté Cloudflare.
  fatalErrors.push("MQTT_USERNAME / FLESPI_MQTT_WORKER_TOKEN manquant");
  console.error(
    "[FATAL] MQTT_USERNAME (ou FLESPI_MQTT_WORKER_TOKEN) absent — MQTT désactivé",
  );
}

const TIPS_GENERATOR_URL = process.env.TIPS_GENERATOR_URL;

// Cooldown 1h par (user_id, appliance_id) — évite spam sur pic persistant.
const lastLivePushByAppliance = new Map();
const LIVE_PUSH_COOLDOWN_MS = 60 * 60 * 1000;

async function evaluateLiveTip(userId, applianceId) {
  const key = `${userId}:${applianceId}`;
  const last = lastLivePushByAppliance.get(key);
  if (last && Date.now() - last < LIVE_PUSH_COOLDOWN_MS) return;

  if (!TIPS_GENERATOR_URL) {
    console.warn("[TIPS] TIPS_GENERATOR_URL non configuré, skip");
    return;
  }

  try {
    const res = await fetch(`${TIPS_GENERATOR_URL}/evaluate-live`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ userId, applianceId }),
    });
    if (!res.ok) {
      console.error(`[TIPS] evaluate-live HTTP ${res.status}`);
      return;
    }
    const json = await res.json();
    if (json.pushed) {
      lastLivePushByAppliance.set(key, Date.now());
      console.log(
        `[TIPS] live push user=${userId} appliance=${applianceId} rule=${json.tip?.ruleId}`,
      );
    }
  } catch (err) {
    console.error("[TIPS] evaluate-live error:", err);
  }
}

// MQTT_TLS=false → broker de test en clair (EMQX local en container).
// En production on reste en TLS : les brokers managés l'exigent.
const mqttScheme = process.env.MQTT_TLS === "false" ? "mqtt" : "mqtts";
const mqttUrl = `${mqttScheme}://${mqttHost}:${mqttPort}`;

console.log(
  `[MQTT5] Connecting to ${mqttUrl} (user=${mqttToken ? "set" : "missing"}, flespi=${isFlespi})`,
);
bootstrap?.setMqttState?.("connecting");

const client = mqttToken ? mqtt.connect(mqttUrl, {
  protocolVersion: 5,
  username: mqttToken,
  // Flespi : token en username ET password (un password vide produit un
  // paquet MQTT5 malformé, refusé en badUsernameOrPassword). Sur un broker
  // standard, MQTT_PASSWORD porte le vrai mot de passe.
  password: mqttPassword,
  clientId: `aricie-worker-${Date.now()}`,

  clean: true,

  keepalive: 30,
  reconnectPeriod: 5000,
  connectTimeout: 15000,

  properties: {
    sessionExpiryInterval: 0,

    // `freeze_timeout` est une propriété propriétaire Flespi (garde la session
    // après déconnexion) : on ne l'envoie que sur ce broker.
    userProperties: {
      ...(isFlespi ? { freeze_timeout: "120" } : {}),
      app: "aricie-mqtt5-worker",
    },
  },
}) : null;

if (client) {
client.on("connect", (packet) => {
  console.log(`[MQTT5] Connected to ${mqttUrl}`);
  bootstrap?.setMqttConnected?.(true);
  bootstrap?.setMqttState?.("connected");

  client.subscribe(
    "aricie/v1/boxes/+/relays/+/ack",
    { qos: 1 },
    (err) => {
      if (err) {
        console.error("[MQTT5] ACK subscribe error:", err);
      } else {
        console.log("[MQTT5] Subscribed to ACK topics");
      }
    },
  );

  client.subscribe(
    "aricie/v1/boxes/+/telemetry",
    { qos: 1 },
    (err) => {
      if (err) {
        console.error("[MQTT5] Telemetry subscribe error:", err);
      } else {
        console.log("[MQTT5] Subscribed to telemetry topics");
      }
    },
  );
});

client.on("reconnect", () => {
  console.log("[MQTT5] Reconnecting...");
  bootstrap?.setMqttState?.("reconnecting");
});

client.on("error", (err) => {
  console.error("[MQTT5] Error:", err);
  // Remonté dans /health : sans ça un échec de connexion sortante (DNS/TLS
  // bloqué côté container) est indistinguable d'un worker simplement inactif.
  bootstrap?.setMqttState?.("error", err?.message ?? err);
});

client.on("close", () => {
  bootstrap?.setMqttConnected?.(false);
  bootstrap?.setMqttState?.("closed");
});
}

async function upsertRealtimePower({ applianceId, userId, boxId, payload }) {
  if (payload.kwh_total === undefined) return;

  const { error } = await supabase
    .from("realtime_power")
    .upsert(
      {
        appliance_id: applianceId,
        user_id: userId,
        box_id: boxId,
        power_kwh: payload.kwh_total,
        instant_power_w: payload.power_w ?? null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "appliance_id" },
    );

  if (error) {
    console.error("[TELEMETRY] realtime_power upsert error:", error);
  }
}

client?.on("message", async (topic, payload, packet) => {
  try {
    const message = JSON.parse(payload.toString());

    // Télémétrie per-boîtier : upsert realtime_power pour chaque appliance du box
    if (topic.startsWith("aricie/v1/boxes/") && topic.endsWith("/telemetry")) {
      const boxUid = topic.split("/")[3];
      const { data: appliances, error: appliancesError } = await supabase
        .from("appliances")
        .select("id, user_id, box_id, relay_index, is_on, boxes!inner(uid_hardware)")
        .eq("boxes.uid_hardware", boxUid);

      if (appliancesError) {
        console.error("[TELEMETRY] appliances lookup error:", appliancesError);
      } else if (Array.isArray(appliances)) {
        stats.telemetryMessages += 1;
        bootstrap?.setStats(stats);
        // payload peut contenir power_w par relais (relay_index -> watts)
        const relayPowers = message.relay_power_w ?? {};
        for (const appliance of appliances) {
          const kwh = message.kwh_total_per_relay?.[appliance.relay_index] ??
            message.kwh_total ?? 0;
          const watts = relayPowers[appliance.relay_index] ??
            message.power_w ?? null;
          await upsertRealtimePower({
            applianceId: appliance.id,
            userId: appliance.user_id,
            boxId: appliance.box_id,
            payload: { kwh_total: kwh, power_w: watts },
          });
          await evaluateLiveTip(appliance.user_id, appliance.id);

          if (message.relays && Array.isArray(message.relays)) {
            const relayStatus = message.relays.find(
              (r) => r.index === appliance.relay_index
            );
            if (relayStatus && typeof relayStatus.status === 'string') {
              const newIsOn = relayStatus.status === 'on';
              if (newIsOn !== appliance.is_on) {
                const { error: syncErr } = await supabase
                  .from('appliances')
                  .update({ is_on: newIsOn })
                  .eq('id', appliance.id);
                if (syncErr) {
                  console.error('[TELEMETRY] is_on sync error:', syncErr);
                } else {
                  console.log(`[TELEMETRY] Appliance ${appliance.id} is_on corrected to ${newIsOn}`);
                }
              }
            }
          }
        }
      }
      return; // télémétrie ≠ ACK, on ne traite pas plus loin
    }

    if (!message.command_id) {
      console.warn("[ACK] Missing command_id:", topic, message);
      return;
    }

    // Fetch the command row to know which appliance/action this ACK concerns
    const { data: cmdRow, error: cmdErr } = await supabase
      .from("device_commands")
      .select("id, action, appliance_id")
      .eq("id", message.command_id)
      .maybeSingle();

    if (cmdErr) {
      console.error("[ACK] Could not fetch device_command:", cmdErr);
      return;
    }

    const updates = {
      status: message.success ? "acknowledged" : "failed",
      acknowledged_at: new Date().toISOString(),
      ack_payload: message,
      error_message: message.success ? null : "Device returned failure ACK",
    };

    const { error: updateError } = await supabase
      .from("device_commands")
      .update(updates)
      .eq("id", message.command_id);

    if (updateError) {
      console.error("[ACK] Supabase update error:", updateError);
      return;
    }

    stats.acksProcessed += 1;
    bootstrap?.setStats(stats);
    console.log(`[ACK] Command ${message.command_id} ${message.success ? 'acknowledged' : 'failed'}`);

    // If acknowledged and we have an appliance_id, update appliance.is_on to reflect the action
    try {
      if (message.success && cmdRow && cmdRow.appliance_id) {
        // Prefer action from the ACK payload if provided, otherwise fall back to stored action
        const action = message.action || cmdRow.action || null;
        if (action === 'on' || action === 'off') {
          const { error: appErr } = await supabase
            .from('appliances')
            .update({ is_on: action === 'on' })
            .eq('id', cmdRow.appliance_id);
          if (appErr) {
            console.error('[ACK] Failed to update appliance state:', appErr);
          } else {
            console.log(`[ACK] Appliance ${cmdRow.appliance_id} is_on set to ${action === 'on'}`);
          }
        }
      }
    } catch (e) {
      console.error('[ACK] Error while updating appliance state:', e);
    }
  } catch (err) {
    console.error("[ACK] Invalid ACK payload:", err);
  }
});

async function claimPendingCommand() {
  const { data: pending, error: selectError } = await supabase
    .from("device_commands")
    .select("id")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (selectError) {
    console.error("[DB] Select pending error:", selectError);
    return null;
  }

  if (!pending) return null;

  const { data: claimed, error: claimError } = await supabase
    .from("device_commands")
    .update({
      status: "processing",
      processing_at: new Date().toISOString(),
      worker_id: WORKER_ID,
    })
    .eq("id", pending.id)
    .eq("status", "pending")
    .select(
      "id, box_uid, relay_index, action, appliance_name, created_at",
    )
    .maybeSingle();

  if (claimError) {
    console.error("[DB] Claim error:", claimError);
    return null;
  }

  return claimed;
}

function publishCommand(command) {
  return new Promise((resolve, reject) => {
    const topic =
      `aricie/v1/boxes/${command.box_uid}/relays/${command.relay_index}/cmd`;

    const payload = JSON.stringify({
      command_id: command.id,
      action: command.action,
      relay_index: command.relay_index,
      appliance_name: command.appliance_name,
      source: "ai_agent",
      issued_at: new Date().toISOString(),
    });

    client.publish(
      topic,
      payload,
      {
        qos: 1,
        retain: false,

        properties: {
          messageExpiryInterval: 30,
          payloadFormatIndicator: true,
          contentType: "application/json",
          userProperties: {
            command_id: command.id,
            source: "ai_agent",
            protocol: "mqtt5",
          },
        },
      },
      (err) => {
        if (err) return reject(err);
        resolve({ topic, payload });
      },
    );
  });
}

async function processOneCommand() {
  if (!client || !client.connected) return;

  const command = await claimPendingCommand();
  if (!command) return;

  try {
    const result = await publishCommand(command);

    const { error } = await supabase
      .from("device_commands")
      .update({
        status: "sent",
        sent_at: new Date().toISOString(),
        error_message: null,
      })
      .eq("id", command.id)
      .eq("status", "processing");

    if (error) {
      console.error("[DB] Mark sent error:", error);
      return;
    }

    stats.commandsSent += 1;
    bootstrap?.setStats(stats);
    console.log(`[CMD] Sent ${command.id} to ${result.topic}`);
  } catch (err) {
    console.error(`[CMD] Publish failed for ${command.id}:`, err);

    await supabase
      .from("device_commands")
      .update({
        status: "failed",
        error_message: String(err),
      })
      .eq("id", command.id);
  }
}

async function markTimeoutCommands() {
  const timeoutDate = new Date(Date.now() - 30_000).toISOString();

  const { error } = await supabase
    .from("device_commands")
    .update({
      status: "timeout",
      error_message: "No device ACK received before timeout",
    })
    .eq("status", "sent")
    .lt("sent_at", timeoutDate);

  if (error) {
    console.error("[DB] Timeout update error:", error);
  }
}

setInterval(processOneCommand, 1000);
setInterval(markTimeoutCommands, 10_000);

console.log(`[WORKER] ${WORKER_ID} started in MQTT 5 mode`);

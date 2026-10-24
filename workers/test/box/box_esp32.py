"""
box_esp32.py — Simulateur ESP32 pour le système Aricie.

Reproduit le comportement attendu d'un boîtier physique ESP32 :
  - Connexion TLS MQTT 5 (EMQX Cloud Serverless par défaut, Flespi toléré)
  - Publie télémétrie toutes les 5 secondes
  - Publie status au démarrage
  - Souscrit aux commandes de relais
  - Acquitte chaque commande reçue

Usage :
  python box_esp32.py <boxUid> [username] [password]

  Les credentials viennent des arguments, sinon de l'environnement :
    MQTT_HOST (défaut mqtt.flespi.io), MQTT_PORT (8883),
    MQTT_USERNAME, MQTT_PASSWORD
  En legacy Flespi, un seul token suffit (il sert de username ET password).

Exemples :
  python box_esp32.py ESP32-A1B2C3D4
  MQTT_HOST=abc123.ala.dedicated.emqx.cloud \
    MQTT_USERNAME=worker-pub MQTT_PASSWORD=secret \
    python box_esp32.py ESP32-A1B2C3D4
"""

import json
import os
import random
import signal
import ssl
import sys
import time
import re

import paho.mqtt.client as mqtt

HOST = os.environ.get("MQTT_HOST", os.environ.get("FLESPI_MQTT_HOST", "mqtt.flespi.io"))
PORT = int(os.environ.get("MQTT_PORT", os.environ.get("FLESPI_MQTT_TCP_PORT", "8883")))
TELEMETRY_INTERVAL = 2  # secondes

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <boxUid> [username] [password]", file=sys.stderr)
    sys.exit(1)

BOX_UID = sys.argv[1]
# Legacy : un seul argument = couple token (username = password), comme Flespi.
_USERNAME = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("MQTT_USERNAME")
_PASSWORD = (
    sys.argv[3]
    if len(sys.argv) > 3
    else os.environ.get("MQTT_PASSWORD", _USERNAME)
)

if not _USERNAME:
    print(
        "Erreur: credentials MQTT manquants (argument <username> ou MQTT_USERNAME)",
        file=sys.stderr,
    )
    sys.exit(1)

if not re.match(r"^[A-Za-z0-9_-]{9,}$", BOX_UID):
    print(f"Erreur: boxUid doit faire > 8 caractères alphanumériques", file=sys.stderr)
    sys.exit(1)

# --- État simulé des 3 relais ---
relays = [
    {"index": 1, "status": "off", "power_w": 0, "kwh": random.uniform(0.5, 3.0)},
    {"index": 2, "status": "off", "power_w": 0, "kwh": random.uniform(0.5, 3.0)},
    {"index": 3, "status": "off", "power_w": 0, "kwh": random.uniform(0.5, 3.0)},
]

TOPIC_TELEMETRY = f"aricie/v1/boxes/{BOX_UID}/telemetry"
TOPIC_STATUS = f"aricie/v1/boxes/{BOX_UID}/status"
TOPIC_CMD = f"aricie/v1/boxes/{BOX_UID}/relays/+/cmd"
TOPIC_CMD_EXACT = f"aricie/v1/boxes/+/relays/+/cmd"

running = True


def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"[{BOX_UID}] Connecté à {HOST}:{PORT}")
        client.subscribe(TOPIC_CMD, qos=1)
        print(f"[{BOX_UID}] Abonné à {TOPIC_CMD}")
        _publish_status(client)
    else:
        print(f"[{BOX_UID}] Échec connexion rc={rc}", file=sys.stderr)


def on_disconnect(client, userdata, rc):
    print(f"[{BOX_UID}] Déconnecté rc={rc}")


def on_message(client, userdata, msg):
    topic = msg.topic
    try:
        payload = json.loads(msg.payload.decode())
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        print(f"[{BOX_UID}] Payload invalide: {e}")
        return

    # Extraire relayIndex du topic
    parts = topic.split("/")
    relay_index = None
    for i, p in enumerate(parts):
        if p == "relays" and i + 1 < len(parts):
            try:
                relay_index = int(parts[i + 1])
            except ValueError:
                pass
            break

    command_id = payload.get("command_id")
    action = payload.get("action")
    source = payload.get("source", "unknown")

    if relay_index is None or command_id is None or action not in ("on", "off"):
        print(f"[{BOX_UID}] Commande ignorée (champs manquants): {payload}")
        return

    if relay_index < 1 or relay_index > len(relays):
        print(f"[{BOX_UID}] Relay {relay_index} hors limites (1-{len(relays)})")
        return

    relay = relays[relay_index - 1]
    relay["status"] = action
    relay["power_w"] = random.uniform(50, 1500) if action == "on" else 0

    print(f"[{BOX_UID}] Relay {relay_index} → {action.upper()} (via {source})")

    # Publier ACK
    ack_topic = f"aricie/v1/boxes/{BOX_UID}/relays/{relay_index}/ack"
    ack_payload = {
        "command_id": command_id,
        "success": True,
        "message": f"Relay {relay_index} turned {action.upper()} successfully",
    }
    client.publish(ack_topic, json.dumps(ack_payload), qos=1)
    print(f"[{BOX_UID}] ACK publié sur {ack_topic}")


def _publish_status(client):
    status_payload = {
        "status": "online",
        "temperature": round(random.uniform(18, 28), 1),
        "humidity": round(random.uniform(30, 70), 1),
        "firmware": "esp32-simulator-1.0",
        "uptime_s": 0,
    }
    client.publish(TOPIC_STATUS, json.dumps(status_payload), qos=1)
    print(f"[{BOX_UID}] Status publié sur {TOPIC_STATUS}")


def _build_telemetry():
    """Construit le payload de télémétrie simulé."""
    return {
        "temperature": round(random.uniform(18, 28), 1),
        "humidity": round(random.uniform(30, 70), 1),
        "relays": [
            {
                "index": r["index"],
                "status": r["status"],
                "power_w": r["power_w"],
            }
            for r in relays
        ],
        "power_w": sum(r["power_w"] for r in relays),
        "kwh_total": round(sum(r["kwh"] for r in relays), 2),
        "kwh_total_per_relay": {str(r["index"]): round(r["kwh"], 2) for r in relays},
        "relay_power_w": {str(r["index"]): r["power_w"] for r in relays},
    }


def publish_telemetry(client):
    """Publie la télémétrie périodique."""
    telemetry = _build_telemetry()
    client.publish(TOPIC_TELEMETRY, json.dumps(telemetry), qos=1)
    relay_status = ", ".join(
        f"R{r['index']}:{r['status']}({r['power_w']}W)" for r in relays
    )
    total_w = sum(r["power_w"] for r in relays)
    print(
        f"[{BOX_UID}] Télémétrie • {telemetry['temperature']}°C "
        f"{telemetry['humidity']}% • {relay_status} • Total: {total_w}W"
    )


def signal_handler(sig, frame):
    global running
    print(f"\n[{BOX_UID}] Arrêt demandé...")
    running = False


# --- MAIN ---
signal.signal(signal.SIGINT, signal_handler)

client = mqtt.Client(
    client_id=f"aricie-box-{BOX_UID}",
    callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
    protocol=mqtt.MQTTv5,
)

client.username_pw_set(_USERNAME, password=_PASSWORD)
client.tls_set(cert_reqs=ssl.CERT_REQUIRED)

client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message

print(f"[{BOX_UID}] Démarrage boîtier ESP32 simulé")
print(f"[{BOX_UID}] Connexion à {HOST}:{PORT}...")
client.connect(HOST, PORT, keepalive=30)

client.loop_start()

last_telemetry = time.time()

while running:
    now = time.time()
    if now - last_telemetry >= TELEMETRY_INTERVAL:
        publish_telemetry(client)
        last_telemetry = now
    time.sleep(0.1)

client.loop_stop()
client.disconnect()
print(f"[{BOX_UID}] Arrêté proprement")

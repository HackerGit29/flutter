import os
import sys
import paho.mqtt.client as mqtt
import ssl

HOST = "mqtt.flespi.io"
PORT = 8883
TOKEN = sys.argv[1]
LABEL = sys.argv[2]

def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        print(f"[{LABEL}] CONNECT OK (rc=0)")
        # Subscribe to a wildcard to validate auth further.
        client.subscribe(f"flespi/interval/+/line/{TOKEN}/+", qos=0)
        print(f"[{LABEL}] subscribed to flespi/interval/+/line/{TOKEN[:6]}/+")
    else:
        print(f"[{LABEL}] CONNECT FAILED rc={reason_code}")
    client.disconnect()

def on_disconnect(client, userdata, flags, reason_code, properties=None):
    print(f"[{LABEL}] disconnected rc={reason_code}")

client = mqtt.Client(
    client_id=f"probe-{LABEL}",
    callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
)
client.username_pw_set(TOKEN, password=None)
client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.tls_set(cert_reqs=ssl.CERT_REQUIRED)
client.tls_insecure_set(False)

try:
    client.connect(HOST, PORT, keepalive=10)
    client.loop_start()
    client.loop_forever() if False else None
except Exception as e:
    print(f"[{LABEL}] EXCEPTION {type(e).__name__}: {e}")
    sys.exit(2)
finally:
    client.loop_stop()
    client.disconnect()
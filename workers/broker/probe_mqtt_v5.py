import sys, ssl, time
import paho.mqtt.client as mqtt

HOST = "mqtt.flespi.io"
PORT = 8883
TOKEN = sys.argv[1]
LABEL = sys.argv[2]

got = {"rc": None}
def on_connect(c, u, f, rc, properties=None):
    got["rc"] = rc
    print(f"[{LABEL}] on_connect rc={rc}", flush=True)
    c.disconnect()

c = mqtt.Client(
    client_id=f"probe-{int(time.time())}",
    protocol=mqtt.MQTTv5,
    callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
)
c.username_pw_set(TOKEN, password="")  # matches what the app does
c.on_connect = on_connect
c.tls_set(cert_reqs=ssl.CERT_REQUIRED)
c.connect(HOST, PORT, 10)
c.loop_start()
deadline = time.time() + 6
while time.time() < deadline and got["rc"] is None:
    time.sleep(0.1)
c.loop_stop()
try: c.disconnect()
except Exception: pass
sys.exit(0 if got["rc"] == 0 else 1)
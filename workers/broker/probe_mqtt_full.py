import sys, ssl, time
import paho.mqtt.client as mqtt

HOST = "mqtt.flespi.io"
PORT = 8883
TOKEN = sys.argv[1]
CID = sys.argv[2]
USER = sys.argv[3]
PWD = sys.argv[4]
LABEL = sys.argv[5]

got = {"rc": None}
def on_connect(c, u, f, rc, properties=None):
    got["rc"] = rc
    print(f"[{LABEL}] on_connect rc={rc} client_id={c._client_id.decode()}", flush=True)
    c.disconnect()

c = mqtt.Client(client_id=CID, callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
c.username_pw_set(USER, password=PWD if PWD else None)
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
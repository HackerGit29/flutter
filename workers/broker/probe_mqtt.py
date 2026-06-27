import sys
import ssl
import time
import paho.mqtt.client as mqtt

HOST = "mqtt.flespi.io"
PORT = 8883
TOKEN = sys.argv[1]
LABEL = sys.argv[2]

state = {"rc": None, "sock_close": False, "connected_flag": False}

def on_connect(c, u, f, rc, properties=None):
    state["rc"] = rc
    state["connected_flag"] = True
    print(f"[{LABEL}] on_connect rc={rc}", flush=True)
    if rc == 0:
        c.subscribe("flespi/interval/+/+/+", qos=0)
        print(f"[{LABEL}] subscribed", flush=True)
    c.disconnect()

def on_disconnect(c, u, rc, properties=None):
    print(f"[{LABEL}] on_disconnect rc={rc}", flush=True)

def on_socket_close(c, u, sock):
    state["sock_close"] = True
    print(f"[{LABEL}] socket closed", flush=True)

c = mqtt.Client(
    client_id=f"probe-{LABEL}-{int(time.time())}",
    callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
)
c.username_pw_set(TOKEN, password=None)
c.on_connect = on_connect
c.on_disconnect = on_disconnect
c.on_socket_close = on_socket_close
c.tls_set(cert_reqs=ssl.CERT_REQUIRED)
c.tls_insecure_set(False)

try:
    c.connect(HOST, PORT, keepalive=10)
    c.loop_start()
    deadline = time.time() + 8
    while time.time() < deadline and not state["connected_flag"]:
        time.sleep(0.1)
    c.loop_stop()
except Exception as e:
    print(f"[{LABEL}] EXCEPTION {type(e).__name__}: {e}", flush=True)
    sys.exit(2)
finally:
    try:
        c.disconnect()
    except Exception:
        pass

if state["rc"] is None:
    print(f"[{LABEL}] NO CONNACK received (timeout or socket dropped)", flush=True)
    sys.exit(3)
sys.exit(0 if state["rc"] == 0 else 1)
/*
  aricie_box_esp32_real.ino

  ESP32 réel pour Aricie :
  - TLS MQTT vers mqtt.flespi.io:8883
  - Publie status au démarrage
  - Publie télémétrie réelle toutes les 2 secondes
  - Lit DHT22 pour température/humidité
  - Lit 3 ACS712 pour courant RMS par ampoule
  - Contrôle 3 relais via commandes MQTT
  - Publie ACK après chaque commande reçue

  Capteurs : DHT22, 3x ACS712 (20A), module relais 4 voies (3 utilisées)
  Libs : WiFi, WiFiClientSecure, PubSubClient, ArduinoJson, DHT, Preferences
*/

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <Preferences.h>

// ===================== CONFIG UTILISATEUR =====================

#define WIFI_SSID       "TON_WIFI"
#define WIFI_PASSWORD   "TON_MOT_DE_PASSE"

#define BOX_UID         "ESP32-A1B2C3D4"
#define FLESPI_TOKEN    "TON_TOKEN_FLESPI"

static const char* MQTT_HOST = "mqtt.flespi.io";
static const uint16_t MQTT_PORT = 8883;

static const uint32_t TELEMETRY_INTERVAL_MS = 2000;
static const uint32_t STATUS_INTERVAL_MS    = 60000;
static const uint32_t KWH_SAVE_INTERVAL_MS  = 60000;

// ponytail: certificat CA à remplacer avant flash, setInsecure() interdit en prod
static const char* FLESPI_ROOT_CA = R"EOF(
-----BEGIN CERTIFICATE-----
COLLER_ICI_LE_CERTIFICAT_CA
-----END CERTIFICATE-----
)EOF";

// ===================== PINOUT ESP32 =====================

static const uint8_t DHT_PIN = 4;
#define DHT_TYPE DHT22

// ADC1 uniquement quand WiFi actif (GPIO34, 35, 32)
static const uint8_t ACS_PINS[3] = {34, 35, 32};

static const uint8_t RELAY_PINS[3] = {16, 17, 18};
static const bool RELAY_ACTIVE_LOW = true;

// ===================== ACS712 =====================

// 5A -> 185.0, 20A -> 100.0, 30A -> 66.0
static const float ACS_SENSITIVITY_MV_PER_A = 100.0f;

// Pont diviseur OUT ACS712 -> ADC ESP32
static const float DIVIDER_R1 = 6800.0f;
static const float DIVIDER_R2 = 12000.0f;
static const float DIVIDER_FACTOR = (DIVIDER_R1 + DIVIDER_R2) / DIVIDER_R2;

static const float MAINS_VOLTAGE_RMS = 220.0f;

// ponytail: 220ms > 10 cycles à 50Hz, suffisant pour RMS correct
static const uint16_t ACS_SAMPLE_MS = 220;
static const float CURRENT_NOISE_FLOOR_A = 0.06f;

// ===================== ÉTAT =====================

struct RelayState {
  uint8_t index;
  bool isOn;
  float currentA;
  float powerW;
  double kwh;
};

RelayState relays[3] = {
  {1, false, 0.0f, 0.0f, 0.0},
  {2, false, 0.0f, 0.0f, 0.0},
  {3, false, 0.0f, 0.0f, 0.0}
};

float acsZeroMv[3] = {2500.0f, 2500.0f, 2500.0f};

DHT dht(DHT_PIN, DHT_TYPE);
WiFiClientSecure secureClient;
PubSubClient mqtt(secureClient);
Preferences prefs;

uint32_t lastTelemetryMs = 0;
uint32_t lastStatusMs = 0;
uint32_t lastKwhSaveMs = 0;
uint32_t lastEnergyMs = 0;

char topicTelemetry[96];
char topicStatus[96];
char topicCmd[96];

// ===================== OUTILS =====================

void setRelayHardware(uint8_t relayIndex, bool on) {
  if (relayIndex < 1 || relayIndex > 3) return;
  uint8_t pin = RELAY_PINS[relayIndex - 1];
  digitalWrite(pin, RELAY_ACTIVE_LOW ? !on : on);
  relays[relayIndex - 1].isOn = on;
}

const char* relayStatusText(bool on) {
  return on ? "on" : "off";
}

bool validBoxUid(const char* uid) {
  size_t len = strlen(uid);
  if (len < 9) return false;
  for (size_t i = 0; i < len; i++) {
    char c = uid[i];
    if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
          (c >= '0' && c <= '9') || c == '_' || c == '-'))
      return false;
  }
  return true;
}

void buildTopics() {
  snprintf(topicTelemetry, sizeof(topicTelemetry),
           "aricie/v1/boxes/%s/telemetry", BOX_UID);
  snprintf(topicStatus, sizeof(topicStatus),
           "aricie/v1/boxes/%s/status", BOX_UID);
  snprintf(topicCmd, sizeof(topicCmd),
           "aricie/v1/boxes/%s/relays/+/cmd", BOX_UID);
}

void loadKwh() {
  prefs.begin("aricie", false);
  for (int i = 0; i < 3; i++) {
    char key[8];
    snprintf(key, sizeof(key), "kwh%d", i + 1);
    relays[i].kwh = prefs.getDouble(key, 0.0);
  }
}

void saveKwh() {
  for (int i = 0; i < 3; i++) {
    char key[8];
    snprintf(key, sizeof(key), "kwh%d", i + 1);
    prefs.putDouble(key, relays[i].kwh);
  }
}

// ===================== WIFI / MQTT =====================

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.print("[WiFi] Connexion");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.printf("\n[WiFi] Connecté IP=%s\n", WiFi.localIP().toString().c_str());
}

void publishStatus(const char* statusValue) {
  JsonDocument doc;
  doc["status"] = statusValue;

  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (!isnan(t)) doc["temperature"] = roundf(t * 10.0f) / 10.0f;
  if (!isnan(h)) doc["humidity"] = roundf(h * 10.0f) / 10.0f;
  doc["firmware"] = "aricie-esp32-real-1.0";
  doc["uptime_s"] = millis() / 1000;

  char payload[384];
  size_t n = serializeJson(doc, payload, sizeof(payload));
  bool ok = mqtt.publish(topicStatus, payload, n);
  Serial.printf("[MQTT] Status %s: %s\n", statusValue, ok ? "OK" : "ECHEC");
}

void publishAck(uint8_t relayIndex, const char* commandId, bool success, const char* message) {
  char ackTopic[112];
  snprintf(ackTopic, sizeof(ackTopic),
           "aricie/v1/boxes/%s/relays/%u/ack", BOX_UID, relayIndex);

  JsonDocument doc;
  doc["command_id"] = commandId;
  doc["success"] = success;
  doc["message"] = message;

  char payload[384];
  size_t n = serializeJson(doc, payload, sizeof(payload));
  mqtt.publish(ackTopic, payload, n);
  Serial.printf("[MQTT] ACK relay %u: %s\n", relayIndex, success ? "OK" : "ECHEC");
}

int extractRelayIndexFromTopic(const char* topic) {
  const char* p = strstr(topic, "/relays/");
  if (!p) return -1;
  int idx = atoi(p + 8);
  return (idx >= 1 && idx <= 3) ? idx : -1;
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  int relayIndex = extractRelayIndexFromTopic(topic);
  if (relayIndex < 0) return;

  JsonDocument doc;
  if (deserializeJson(doc, payload, length)) {
    Serial.println("[CMD] JSON invalide");
    return;
  }

  const char* commandId = doc["command_id"] | "";
  const char* action = doc["action"] | "";
  const char* source = doc["source"] | "unknown";

  if (strlen(commandId) == 0) {
    publishAck(relayIndex, "unknown", false, "Missing command_id");
    return;
  }

  bool turnOn;
  if (strcmp(action, "on") == 0) turnOn = true;
  else if (strcmp(action, "off") == 0) turnOn = false;
  else {
    publishAck(relayIndex, commandId, false, "Invalid action");
    return;
  }

  setRelayHardware(relayIndex, turnOn);

  char msg[96];
  snprintf(msg, sizeof(msg), "Relay %d turned %s successfully",
           relayIndex, turnOn ? "ON" : "OFF");
  Serial.printf("[CMD] Relay %d -> %s via %s\n", relayIndex, turnOn ? "ON" : "OFF", source);
  publishAck(relayIndex, commandId, true, msg);
}

void connectMQTT() {
  if (mqtt.connected()) return;
  while (!mqtt.connected()) {
    Serial.printf("[MQTT] Connexion %s:%u...\n", MQTT_HOST, MQTT_PORT);
    char clientId[64];
    snprintf(clientId, sizeof(clientId), "aricie-box-%s", BOX_UID);

    // ponytail: Last Will pour status offline si l'ESP32 crash
    if (mqtt.connect(clientId, FLESPI_TOKEN, FLESPI_TOKEN,
                     topicStatus, 0, false, "{\"status\":\"offline\"}")) {
      Serial.println("[MQTT] Connecté");
      mqtt.subscribe(topicCmd, 1);
      publishStatus("online");
    } else {
      Serial.printf("[MQTT] Echec rc=%d, retry 3s\n", mqtt.state());
      delay(3000);
    }
  }
}

// ===================== CAPTEURS =====================

float readAdcSensorMv(uint8_t pin) {
  return (float)analogReadMilliVolts(pin) * DIVIDER_FACTOR;
}

float calibrateAcsZeroMv(uint8_t channel) {
  double sum = 0.0;
  const uint16_t samples = 800;
  for (uint16_t i = 0; i < samples; i++) {
    sum += readAdcSensorMv(ACS_PINS[channel]);
    delayMicroseconds(500);
  }
  return (float)(sum / samples);
}

float readAcsCurrentRmsA(uint8_t channel) {
  uint32_t start = millis();
  double sumSq = 0.0;
  uint32_t count = 0;

  while ((millis() - start) < ACS_SAMPLE_MS) {
    float centered = readAdcSensorMv(ACS_PINS[channel]) - acsZeroMv[channel];
    sumSq += (double)centered * (double)centered;
    count++;
    delayMicroseconds(500);
  }

  if (count == 0) return 0.0f;
  float currentA = sqrt(sumSq / count) / ACS_SENSITIVITY_MV_PER_A;
  return (currentA < CURRENT_NOISE_FLOOR_A) ? 0.0f : currentA;
}

void updateMeasurements() {
  for (int i = 0; i < 3; i++) {
    float a = readAcsCurrentRmsA(i);
    // ponytail: force zéro si relais OFF, enlever si détection fuite souhaitée
    if (!relays[i].isOn) a = 0.0f;
    relays[i].currentA = a;
    relays[i].powerW = a * MAINS_VOLTAGE_RMS;
  }
}

void updateEnergyKwh() {
  uint32_t now = millis();
  if (lastEnergyMs == 0) { lastEnergyMs = now; return; }
  float deltaH = (now - lastEnergyMs) / 3600000.0f;
  lastEnergyMs = now;
  for (int i = 0; i < 3; i++)
    relays[i].kwh += ((double)relays[i].powerW * deltaH) / 1000.0;
}

// ===================== TÉLÉMÉTRIE =====================

void publishTelemetry() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();

  updateMeasurements();
  updateEnergyKwh();

  JsonDocument doc;
  doc["temperature"] = isnan(t) ? (JsonVariant)nullptr : JsonVariant(roundf(t * 10.0f) / 10.0f);
  doc["humidity"] = isnan(h) ? (JsonVariant)nullptr : JsonVariant(roundf(h * 10.0f) / 10.0f);

  JsonArray arr = doc["relays"].to<JsonArray>();
  JsonObject kwhPR = doc["kwh_total_per_relay"].to<JsonObject>();
  JsonObject pwrPR = doc["relay_power_w"].to<JsonObject>();
  JsonObject curPR = doc["relay_current_a"].to<JsonObject>();

  float totalW = 0.0f;
  double totalKwh = 0.0;

  for (int i = 0; i < 3; i++) {
    JsonObject r = arr.add<JsonObject>();
    r["index"] = relays[i].index;
    r["status"] = relayStatusText(relays[i].isOn);
    r["power_w"] = roundf(relays[i].powerW * 10.0f) / 10.0f;

    char key[4];
    snprintf(key, sizeof(key), "%u", relays[i].index);
    kwhPR[key] = round(relays[i].kwh * 1000.0) / 1000.0;
    pwrPR[key] = roundf(relays[i].powerW * 10.0f) / 10.0f;
    curPR[key] = roundf(relays[i].currentA * 1000.0f) / 1000.0f;

    totalW += relays[i].powerW;
    totalKwh += relays[i].kwh;
  }

  doc["power_w"] = roundf(totalW * 10.0f) / 10.0f;
  doc["kwh_total"] = round(totalKwh * 1000.0) / 1000.0;
  doc["uptime_s"] = millis() / 1000;

  char payload[1024];
  size_t n = serializeJson(doc, payload, sizeof(payload));
  if (n == 0 || n >= sizeof(payload)) return;

  mqtt.publish(topicTelemetry, payload, n);
  Serial.printf("[TEL] R1=%s %.1fW R2=%s %.1fW R3=%s %.1fW Total=%.1fW\n",
                relayStatusText(relays[0].isOn), relays[0].powerW,
                relayStatusText(relays[1].isOn), relays[1].powerW,
                relayStatusText(relays[2].isOn), relays[2].powerW, totalW);
}

// ===================== SETUP / LOOP =====================

void setup() {
  Serial.begin(115200);
  delay(500);

  if (!validBoxUid(BOX_UID)) {
    Serial.println("[BOOT] BOX_UID invalide");
    while (true) delay(1000);
  }

  buildTopics();

  for (int i = 0; i < 3; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    setRelayHardware(i + 1, false);
  }

  for (int i = 0; i < 3; i++)
    pinMode(ACS_PINS[i], INPUT);

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  dht.begin();
  loadKwh();
  connectWiFi();

  secureClient.setCACert(FLESPI_ROOT_CA);
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(1024);
  mqtt.setKeepAlive(30);
  mqtt.setSocketTimeout(10);

  Serial.println("[ACS] Calibration zéro (relais OFF)...");
  delay(1000);
  for (int i = 0; i < 3; i++) {
    acsZeroMv[i] = calibrateAcsZeroMv(i);
    Serial.printf("[ACS] Canal %d offset=%.2f mV\n", i + 1, acsZeroMv[i]);
  }

  connectMQTT();

  lastTelemetryMs = millis();
  lastStatusMs = millis();
  lastKwhSaveMs = millis();
  lastEnergyMs = millis();
}

void loop() {
  connectWiFi();
  connectMQTT();
  mqtt.loop();

  uint32_t now = millis();

  if (now - lastTelemetryMs >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryMs = now;
    publishTelemetry();
  }

  if (now - lastStatusMs >= STATUS_INTERVAL_MS) {
    lastStatusMs = now;
    publishStatus("online");
  }

  if (now - lastKwhSaveMs >= KWH_SAVE_INTERVAL_MS) {
    lastKwhSaveMs = now;
    saveKwh();
  }
}

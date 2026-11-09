#include <Arduino.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266WiFi.h>
#include <Servo.h>
#include <WiFiClientSecureBearSSL.h>
#include <time.h>

#include "secrets.h"
#include "supabase_root_ca.h"

namespace {
// Pin dan logika mengikuti firmware lama yang sudah bekerja.
constexpr uint8_t SERVO_PIN = D1;
constexpr uint8_t LIGHT_SENSOR_PIN = D6;  // DO modul LDR
constexpr uint8_t RAIN_SENSOR_PIN = D7;   // DO modul hujan
constexpr uint32_t SENSOR_INTERVAL_MS = 100;
constexpr uint32_t LIGHT_DEBOUNCE_MS = 100;
constexpr uint32_t TELEMETRY_INTERVAL_MS = 15000;
constexpr uint32_t MIN_EVENT_UPLOAD_INTERVAL_MS = 1500;
constexpr uint16_t HTTP_TIMEOUT_MS = 1500;
constexpr uint16_t COMMAND_HTTP_TIMEOUT_MS = 1500;
// Jeda ini dihitung setelah request selesai agar loop sensor sempat berjalan.
constexpr uint32_t COMMAND_INTERVAL_MS = 1000;
constexpr uint32_t WIFI_RETRY_INTERVAL_MS = 12000;
constexpr uint32_t CLOCK_LOG_INTERVAL_MS = 10000;

Servo clotheslineServo;
BearSSL::X509List trustAnchor(SUPABASE_ROOT_CA);

bool telemetryPending = false;
bool hasSensorSample = false;
bool rainDetected = true;  // fail-safe: bila sensor gagal, tutup jemuran.
int rainValue = 0;
float lightPercent = 0;
bool previousRainDetected = true;
float previousLightPercent = 0;
bool darkDetected = false;
bool darkCandidate = false;
uint32_t darkCandidateAt = 0;
String currentMode = "automatic";
String servoPosition = "closed";
uint32_t lastSensorAt = 0;
uint32_t lastTelemetryAt = 0;
uint32_t lastCommandAt = 0;
uint32_t lastWifiAttemptAt = 0;
uint32_t lastSensorLogAt = 0;
uint32_t lastClockLogAt = 0;
bool wifiWasConnected = false;
bool clockWasSynchronized = false;

String functionUrl(const char* name) {
  String base(SUPABASE_URL);
  while (base.endsWith("/")) base.remove(base.length() - 1);
  return base + "/functions/v1/" + name;
}

int httpPost(const String& url, const String& body,
             String* responseBody = nullptr,
             uint16_t timeoutMs = HTTP_TIMEOUT_MS) {
  BearSSL::WiFiClientSecure client;
  client.setTrustAnchors(&trustAnchor);
  // Batasi jeda saat internet bermasalah agar pembacaan sensor lokal cepat lanjut.
  client.setTimeout(timeoutMs);

  HTTPClient http;
  http.setTimeout(timeoutMs);
  if (!http.begin(client, url)) return -1;
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_PUBLISHABLE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_PUBLISHABLE_KEY);
  http.addHeader("x-device-id", DEVICE_ID);
  http.addHeader("x-device-secret", DEVICE_SECRET);
  int code = http.POST(body);
  if (responseBody && code > 0) *responseBody = http.getString();
  http.end();
  return code;
}

void setPosition(const String& target, bool fromRain = false) {
  if (target == "open" && rainDetected) {
    Serial.println("Buka ditolak: sensor hujan basah.");
    return;
  }
  if (target != "open" && target != "closed") return;
  if (servoPosition == target) return;
  clotheslineServo.write(target == "open" ? SERVO_OPEN_ANGLE : SERVO_CLOSED_ANGLE);
  servoPosition = target;
  telemetryPending = true;
  Serial.printf("Jemuran %s%s\n", target == "open" ? "dibuka" : "ditutup", fromRain ? " karena hujan" : "");
}

void sampleSensors(bool applyAutomaticRules = true) {
  // Sensor digital seperti pada kode lama: hujan aktif LOW, gelap aktif HIGH.
  const int rawRain = digitalRead(RAIN_SENSOR_PIN);
  const bool nextRain = rawRain == LOW;
  const bool rawDark = digitalRead(LIGHT_SENSOR_PIN) == HIGH;
  bool wasRaining = rainDetected;
  rainDetected = nextRain;

  if (!hasSensorSample) {
    darkDetected = rawDark;
    darkCandidate = rawDark;
    darkCandidateAt = millis();
  } else if (rawDark != darkCandidate) {
    darkCandidate = rawDark;
    darkCandidateAt = millis();
  } else if (darkCandidate != darkDetected &&
             millis() - darkCandidateAt >= LIGHT_DEBOUNCE_MS) {
    darkDetected = darkCandidate;
  }

  // Modul LDR lama hanya memberi status terang/gelap digital, bukan persentase analog.
  rainValue = rawRain;
  lightPercent = darkDetected ? 0.0f : 100.0f;
  if (!hasSensorSample || rainDetected != previousRainDetected || lightPercent != previousLightPercent) {
    telemetryPending = true;
  }
  previousRainDetected = rainDetected;
  previousLightPercent = lightPercent;
  hasSensorSample = true;
  if (millis() - lastSensorLogAt >= 2000) {
    lastSensorLogAt = millis();
    Serial.printf("Sensor hujan DO=%s (%s), LDR=%s, mode=%s, posisi=%s\n",
                  rawRain == LOW ? "LOW" : "HIGH",
                  rainDetected ? "BASAH" : "KERING",
                  darkDetected ? "GELAP" : "TERANG",
                  currentMode.c_str(), servoPosition.c_str());
  }

  // Proteksi hujan selalu aktif, termasuk saat mode Manual atau internet terputus.
  if (rainDetected) {
    setPosition("closed", true);
    return;
  }
  if (!applyAutomaticRules || currentMode != "automatic") return;

  // Modul LDR digital hanya melaporkan terang atau gelap.
  if (darkDetected && servoPosition != "closed") setPosition("closed");
  if (!darkDetected && servoPosition != "open") setPosition("open");
  if (wasRaining && !rainDetected) Serial.println("Sensor kembali kering.");
}

bool sendTelemetry() {
  JsonDocument body;
  body["mode"] = currentMode;
  body["servo_position"] = servoPosition;
  body["rain_value"] = rainValue;
  body["light_percent"] = lightPercent;
  body["rain_detected"] = rainDetected;
  String encoded;
  serializeJson(body, encoded);
  String response;
  int code = httpPost(functionUrl("device-data"), encoded, &response);
  Serial.printf("Upload sensor: HTTP %d\n", code);
  if (code < 0) {
    Serial.printf("Detail koneksi HTTPS: %s\n", HTTPClient::errorToString(code).c_str());
  } else if (code >= 300) {
    Serial.printf("Respons Supabase: %s\n", response.c_str());
  }
  return code >= 200 && code < 300;
}

void saveMode() {
  EEPROM.write(0, currentMode == "manual" ? 1 : 0);
  EEPROM.commit();
}

void acknowledgeCommand(const String& commandId, bool success, const char* message) {
  JsonDocument body;
  body["action"] = "ack";
  body["command_id"] = commandId;
  body["success"] = success;
  body["message"] = message;
  String encoded;
  serializeJson(body, encoded);
  int code = httpPost(functionUrl("device-commands"), encoded);
  Serial.printf("Ack perintah: HTTP %d\n", code);
}

bool pollCommands() {
  JsonDocument request;
  request["action"] = "next";
  String encoded;
  serializeJson(request, encoded);
  String response;
  int code = httpPost(functionUrl("device-commands"), encoded, &response,
                      COMMAND_HTTP_TIMEOUT_MS);
  // Sensor bisa berubah selama permintaan HTTPS. Periksa hujan sebelum buka,
  // tetapi jangan jalankan aturan otomatis sebelum perintah aplikasi diterapkan.
  sampleSensors(false);
  if (code < 200 || code >= 300) return false;

  JsonDocument result;
  if (deserializeJson(result, response)) return false;
  JsonVariant command = result["command"];
  if (command.isNull()) return false;
  String id = command["id"] | "";
  String type = command["command_type"] | "";
  if (id.isEmpty()) return false;

  bool success = false;
  const char* message = "Perintah tidak didukung.";
  if (type == "set_mode") {
    String targetMode = command["payload"]["mode"] | "";
    if (targetMode == "automatic" || targetMode == "manual") {
      currentMode = targetMode;
      saveMode();
      telemetryPending = true;
      if (currentMode == "automatic") sampleSensors();
      success = true;
      message = "Mode diterapkan.";
    }
  } else if (type == "close") {
    setPosition("closed");
    success = true;
    message = "Jemuran ditutup.";
  } else if (type == "open") {
    if (currentMode != "manual") {
      message = "Perangkat tidak sedang dalam mode Manual.";
    } else if (rainDetected) {
      message = "Pembukaan ditolak karena sensor mendeteksi hujan.";
    } else {
      setPosition("open");
      success = true;
      message = "Jemuran dibuka.";
    }
  }
  // setPosition() sudah menulis sudut servo. Baru setelah gerakan dimulai,
  // kirim status Realtime lalu ACK ke Supabase.
  telemetryPending = true;
  const bool statusUploaded = sendTelemetry();
  lastTelemetryAt = millis();
  if (statusUploaded) telemetryPending = false;
  acknowledgeCommand(id, success, message);
  return true;
}

void keepWifiConnecting() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!wifiWasConnected) {
      wifiWasConnected = true;
      Serial.printf("Wi-Fi tersambung. IP=%s, RSSI=%d dBm\n",
                    WiFi.localIP().toString().c_str(), WiFi.RSSI());
      configTime(0, 0, "pool.ntp.org", "time.google.com", "time.cloudflare.com");
      Serial.println("Meminta sinkronisasi jam dari NTP...");
    }
    return;
  }
  if (wifiWasConnected) {
    wifiWasConnected = false;
    Serial.println("Wi-Fi terputus.");
  }
  uint32_t now = millis();
  if (now - lastWifiAttemptAt < WIFI_RETRY_INTERVAL_MS) return;
  lastWifiAttemptAt = now;
  Serial.println("Mencoba menyambung ulang Wi-Fi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}
}  // namespace

void setup() {
  Serial.begin(115200);
  pinMode(LIGHT_SENSOR_PIN, INPUT);
  pinMode(RAIN_SENSOR_PIN, INPUT);
  clotheslineServo.attach(SERVO_PIN);
  clotheslineServo.write(SERVO_CLOSED_ANGLE);
  servoPosition = "closed";
  EEPROM.begin(4);
  currentMode = EEPROM.read(0) == 1 ? "manual" : "automatic";
  Serial.println("Sensor digital aktif: LDR=D6, hujan=D7, servo=D1.");

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  // Sertifikat HTTPS memerlukan jam perangkat yang benar untuk validasi TLS.
  configTime(0, 0, "pool.ntp.org", "time.google.com", "time.cloudflare.com");
  lastWifiAttemptAt = millis();
  Serial.println("Smart Clothesline siap. Otomatis lokal aktif.");
}

void loop() {
  uint32_t now = millis();

  // Pembacaan dan aturan lokal didahulukan; berjalan tanpa koneksi internet.
  if (now - lastSensorAt >= SENSOR_INTERVAL_MS) {
    lastSensorAt = now;
    sampleSensors();
  }

  keepWifiConnecting();
  if (WiFi.status() != WL_CONNECTED) return;
  const time_t currentTime = time(nullptr);
  if (currentTime < 1704067200) {
    if (now - lastClockLogAt >= CLOCK_LOG_INTERVAL_MS) {
      lastClockLogAt = now;
      Serial.println("Menunggu sinkronisasi waktu NTP sebelum koneksi HTTPS...");
    }
    return;
  }
  if (!clockWasSynchronized) {
    clockWasSynchronized = true;
    Serial.printf("Waktu NTP tersinkron: %s", ctime(&currentTime));
  }

  if (now - lastCommandAt >= COMMAND_INTERVAL_MS) {
    // Request HTTPS bersifat sinkron. Beri jeda sensor setelah request selesai.
    pollCommands();
    lastCommandAt = millis();
  }
  now = millis();
  const bool periodicUploadDue = now - lastTelemetryAt >= TELEMETRY_INTERVAL_MS;
  const bool eventUploadDue = telemetryPending && now - lastTelemetryAt >= MIN_EVENT_UPLOAD_INTERVAL_MS;
  if (periodicUploadDue || eventUploadDue) {
    if (sendTelemetry()) telemetryPending = false;
    lastTelemetryAt = millis();
  }
}

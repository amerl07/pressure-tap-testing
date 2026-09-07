#include <Wire.h>
#include <math.h>
#include "FS.h"
#include "LittleFS.h"

TwoWire I2C_1 = TwoWire(0);
TwoWire I2C_2 = TwoWire(1);

#define P_FS_PA 6894.76
#define RHO 1.225
#define BOOT_BUTTON 38
#define LED_PIN 13

float zero1 = 0;
float zero2 = 0;
File dataFile;
bool logging = false;
bool wasPressed = false;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 200;  // ms — ignore button changes faster than this

float readPressure(TwoWire &bus) {
  bus.requestFrom(0x28, 2);
  if (bus.available() >= 2) {
    uint8_t high = bus.read();
    uint8_t low = bus.read();
    uint8_t status = (high >> 6) & 0x03;
    if (status == 2 || status == 3) return NAN;
    uint16_t raw = ((high & 0x3F) << 8) | low;
    float pressure = ((float)raw - 1638.0) / (14745.0 - 1638.0) * 2.0 - 1.0;
    pressure *= P_FS_PA;
    return pressure;
  }
  return NAN;
}

void setup() {
  Serial.begin(115200);
  pinMode(BOOT_BUTTON, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  I2C_1.begin(22, 20);
  I2C_2.begin(14, 32);

  if (!LittleFS.begin(true)) {
    Serial.println("LittleFS mount FAILED");
    while (1);
  }

  // Flash LED 3 times to indicate calibration starting
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH); delay(200);
    digitalWrite(LED_PIN, LOW);  delay(200);
  }

  Serial.println("Calibrating... keep sensors still");
  delay(1000);
  float sum1 = 0, sum2 = 0;
  for (int i = 0; i < 50; i++) {
    sum1 += readPressure(I2C_1);
    sum2 += readPressure(I2C_2);
    delay(20);
  }
  zero1 = sum1 / 50.0;
  zero2 = sum2 / 50.0;
  Serial.print("Zero 1: "); Serial.println(zero1);
  Serial.print("Zero 2: "); Serial.println(zero2);
  Serial.println("Calibration done.");
  Serial.println("Press BOOT button to START logging.");

  // Solid LED on = ready and waiting for button press
  digitalWrite(LED_PIN, HIGH);
}

void loop() {
  bool buttonPressed = (digitalRead(BOOT_BUTTON) == LOW);

  if (buttonPressed != wasPressed && (millis() - lastDebounceTime) > debounceDelay) {
    lastDebounceTime = millis();
    wasPressed = buttonPressed;

    if (buttonPressed) {
      if (!logging) {
        char filename[20];
        int fileNum = 0;
        do {
          snprintf(filename, sizeof(filename), "/run%03d.csv", fileNum++);
        } while (LittleFS.exists(filename));

        dataFile = LittleFS.open(filename, "w");
        if (!dataFile) {
          Serial.println("Failed to open file");
          return;
        }
        dataFile.println("time_ms,pitot_pa,tap_pa,airspeed_ms,Cp");
        logging = true;
        Serial.print("Logging started: ");
        Serial.println(filename);
        Serial.println("Press BOOT button to STOP logging.");

      } else {
        dataFile.flush();
        dataFile.close();
        logging = false;
        Serial.println("Logging stopped safely. You can now unplug.");
        Serial.println("Press BOOT button to start a new run.");

        // Solid LED off = logging stopped, safe to unplug
        digitalWrite(LED_PIN, LOW);
      }
    }
  }

  if (!logging) return;

  // Blink LED while logging
  static unsigned long lastBlink = 0;
  static bool ledState = false;
  if (millis() - lastBlink >= 500) {
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState);
    lastBlink = millis();
  }

  float p_pitot = readPressure(I2C_1) - zero1;
  float p_tap   = readPressure(I2C_2) - zero2;

  float airspeed = 0;
  if (!isnan(p_pitot) && p_pitot > 0) {
    airspeed = sqrt(2.0 * p_pitot / RHO);
  }

  float Cp = NAN;
  if (!isnan(p_pitot) && !isnan(p_tap) && p_pitot > 5.0) {
    Cp = p_tap / p_pitot;
  }

  dataFile.print(millis());
  dataFile.print(",");
  dataFile.print(p_pitot);
  dataFile.print(",");
  dataFile.print(p_tap);
  dataFile.print(",");
  dataFile.print(airspeed);
  dataFile.print(",");
  if (!isnan(Cp)) dataFile.println(Cp);
  else dataFile.println("NaN");

  static int rowCount = 0;
  if (++rowCount >= 10) {
    dataFile.flush();
    rowCount = 0;
  }

  Serial.print("Pitot_Pa:"); Serial.print(p_pitot);
  Serial.print(",Tap_Pa:"); Serial.print(p_tap);
  Serial.print(",Airspeed_ms:"); Serial.print(airspeed);
  Serial.print(",Cp:"); Serial.println(isnan(Cp) ? 0 : Cp);

  delay(100);
}
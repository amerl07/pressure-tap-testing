// I2C 诊断程序：每 2 秒扫描一次两条总线，并读一次原始数据
// 正常结果：两条总线都找到 0x28
#include <Wire.h>

TwoWire I2C_1 = TwoWire(0);   // Pitot: SDA 22, SCL 20
TwoWire I2C_2 = TwoWire(1);   // Tap:   SDA 14, SCL 32

void scan(TwoWire &bus, const char *name) {
  Serial.print(name);
  Serial.print(": ");
  bool found = false;
  for (uint8_t addr = 1; addr < 127; addr++) {
    bus.beginTransmission(addr);
    if (bus.endTransmission() == 0) {
      Serial.printf("0x%02X ", addr);
      found = true;
    }
  }
  if (!found) Serial.print("nothing found");
  Serial.println();
}

void rawRead(TwoWire &bus, const char *name) {
  uint8_t n = bus.requestFrom(0x28, 2);
  Serial.print(name);
  if (n < 2) {
    Serial.println(" raw: no response");
    return;
  }
  uint8_t high = bus.read();
  uint8_t low = bus.read();
  uint8_t status = (high >> 6) & 0x03;
  uint16_t raw = ((high & 0x3F) << 8) | low;
  Serial.printf(" raw: status=%u counts=%u\n", status, raw);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  I2C_1.begin(22, 20);
  I2C_2.begin(14, 32);
  Serial.println("I2C scan starting...");
}

void loop() {
  scan(I2C_1, "Pitot bus (22/20)");
  scan(I2C_2, "Tap bus   (14/32)");
  rawRead(I2C_1, "Pitot");
  rawRead(I2C_2, "Tap  ");
  Serial.println("---");
  delay(2000);
}

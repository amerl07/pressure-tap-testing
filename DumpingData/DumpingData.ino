#include "FS.h"
#include "LittleFS.h"

void printStorageInfo() {
  Serial.println("\n=== STORAGE INFO ===");
  Serial.print("Total space: ");
  Serial.print(LittleFS.totalBytes());
  Serial.println(" bytes");
  Serial.print("Used space: ");
  Serial.print(LittleFS.usedBytes());
  Serial.println(" bytes");
  Serial.print("Free space: ");
  Serial.print(LittleFS.totalBytes() - LittleFS.usedBytes());
  Serial.println(" bytes");
  Serial.println("====================\n");
}

void listFiles() {
  Serial.println("=== FILES ON DEVICE ===");
  File root = LittleFS.open("/");
  File entry = root.openNextFile();
  while (entry) {
    Serial.print("  ");
    Serial.print(entry.name());
    Serial.print("  —  ");
    Serial.print(entry.size());
    Serial.println(" bytes");
    entry = root.openNextFile();
  }
  Serial.println("=======================\n");
}

void dumpFiles() {
  bool foundAny = false;
  for (int i = 0; i < 100; i++) {
    char filename[20];
    snprintf(filename, sizeof(filename), "/run%03d.csv", i);
    if (!LittleFS.exists(filename)) continue;
    foundAny = true;

    Serial.print("\n--- START OF ");
    Serial.print(filename);
    Serial.println(" ---");

    File dataFile = LittleFS.open(filename, "r");
    while (dataFile.available()) {
      Serial.write(dataFile.read());
    }
    dataFile.close();

    Serial.print("--- END OF ");
    Serial.print(filename);
    Serial.println(" ---\n");
  }
  if (!foundAny) Serial.println("No run files found.");
  Serial.println("Data dump complete.");
  Serial.println("Type 'delete' and hit send to delete all run files.");
}

void deleteFiles() {
  int count = 0;
  for (int i = 0; i < 100; i++) {
    char filename[20];
    snprintf(filename, sizeof(filename), "/run%03d.csv", i);
    if (LittleFS.exists(filename)) {
      LittleFS.remove(filename);
      Serial.print("Deleted: ");
      Serial.println(filename);
      count++;
    }
  }
  if (count == 0) Serial.println("No files to delete.");
  else Serial.println("All run files deleted. Storage cleared.");
  printStorageInfo();
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  if (!LittleFS.begin(true)) {
    Serial.println("LittleFS mount FAILED");
    return;
  }

  printStorageInfo();
  listFiles();
  dumpFiles();
}

void loop() {
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd == "delete") {
      deleteFiles();
    } else {
      Serial.println("Unknown command. Type 'delete' to delete all run files.");
    }
  }
}
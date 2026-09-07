import serial
import serial.tools.list_ports
import time
import os

# Auto-detect ESP32 port
def find_esp32_port():
    ports = serial.tools.list_ports.comports()
    for port in ports:
        desc = port.description or ""
        dev = port.device or ""
        if ('CP210' in desc or 'USB' in desc or 'CH340' in desc or 'SLAB' in desc
                or 'COM' in dev or 'usbserial' in dev or 'usbmodem' in dev):
            return port.device
    return None

# Settings
BAUD_RATE = 115200
OUTPUT_DIR = os.path.expanduser("~/Desktop/esp32_data")
os.makedirs(OUTPUT_DIR, exist_ok=True)

port = find_esp32_port()
if port is None:
    print("Could not auto-detect the ESP32. Available ports:")
    for p in serial.tools.list_ports.comports():
        print(f"  {p.device}  —  {p.description}")
    port = input("Type the port to use (e.g. /dev/cu.usbserial-58900035621): ").strip()

print(f"Connecting to {port}...")
ser = serial.Serial(port, BAUD_RATE, timeout=2)
time.sleep(2)

# Send reset signal
ser.setDTR(False)
time.sleep(0.1)
ser.setDTR(True)
time.sleep(2)

print("Reading data from ESP32...")
current_file = None
output_file = None
capturing = False

while True:
    line = ser.readline().decode('utf-8', errors='ignore').strip()
    if not line:
        continue

    print(line)  # show in terminal

    # Detect start of file
    if line.startswith("--- START OF"):
        filename = line.replace("--- START OF ", "").replace(" ---", "").strip()
        filename = filename.replace("/", "")
        filepath = os.path.join(OUTPUT_DIR, filename)
        output_file = open(filepath, 'w')
        capturing = True
        print(f"Saving to {filepath}")
        continue

    # Detect end of file
    if line.startswith("--- END OF"):
        if output_file:
            output_file.close()
            output_file = None
        capturing = False
        print(f"File saved!")
        continue

    # Detect all done
    if "Data dump complete" in line or "No run files found" in line:
        print("\nAll files saved to:", OUTPUT_DIR)
        # Ask to delete
        answer = input("\nType 'delete' to clear ESP32 storage, or press Enter to skip: ")
        if answer.strip() == 'delete':
            ser.write(b'delete\n')
            deadline = time.time() + 3  # stop waiting after 3s of no new data
            while time.time() < deadline:
                if ser.in_waiting:
                    print(ser.readline().decode('utf-8', errors='ignore').strip())
                    deadline = time.time() + 3  # got data, extend the wait a bit
        break

    # Write CSV data
    if capturing and output_file:
        output_file.write(line + '\n')

ser.close()
print("Done!")
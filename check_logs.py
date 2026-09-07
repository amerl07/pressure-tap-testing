import serial
import serial.tools.list_ports
import time

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

BAUD_RATE = 115200

port = find_esp32_port()
if port is None:
    print("Could not auto-detect the ESP32. Available ports:")
    for p in serial.tools.list_ports.comports():
        print(f"  {p.device}  —  {p.description}")
    port = input("Type the port to use (e.g. /dev/cu.usbserial-58900035621): ").strip()

print(f"Connecting to {port}...")
ser = serial.Serial(port, BAUD_RATE, timeout=2)
time.sleep(2)

# Send reset signal so the ESP32 re-runs setup() (this board must be running
# DumpingData.ino — it lists and dumps files automatically on boot)
ser.setDTR(False)
time.sleep(0.1)
ser.setDTR(True)
time.sleep(2)

print("Checking for existing run files...\n")

files_found = []
in_file_list = False
in_dump_body = False

while True:
    line = ser.readline().decode('utf-8', errors='ignore').strip()
    if not line:
        continue

    # Start/end of the file listing section
    if "FILES ON DEVICE" in line:
        in_file_list = True
        continue
    if in_file_list and line.startswith("====="):
        in_file_list = False
        continue
    if in_file_list:
        files_found.append(line)
        continue

    # Skip over the raw CSV content of each dumped file — we don't need it
    if line.startswith("--- START OF"):
        in_dump_body = True
        continue
    if line.startswith("--- END OF"):
        in_dump_body = False
        continue
    if in_dump_body:
        continue

    # Reached the end of the boot sequence
    if "Data dump complete" in line or "No run files found" in line:
        break

if files_found:
    print(f"Found {len(files_found)} run file(s) on the ESP32:")
    for f in files_found:
        print(f"  {f}")
else:
    print("No run files found on the ESP32.")

ser.close()

if files_found:
    answer = input("\nType 'delete' to erase these files from the ESP32, or press Enter to leave them: ").strip()
    if answer == 'delete':
        # Reopen the port to send the delete command
        ser = serial.Serial(port, BAUD_RATE, timeout=2)
        time.sleep(0.5)
        ser.write(b'delete\n')

        deadline = time.time() + 3  # stop waiting after 3s of no new data
        while time.time() < deadline:
            if ser.in_waiting:
                print(ser.readline().decode('utf-8', errors='ignore').strip())
                deadline = time.time() + 3
        ser.close()
        print("\nDone.")
    else:
        print("\nFiles left untouched.")
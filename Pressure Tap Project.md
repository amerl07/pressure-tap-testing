# **C-Channel Pressure Tap Validation Project**

## **Project Overview**

The purpose of this project is to perform a quick on-car aerodynamic validation of the C-channel by measuring pressure coefficient (Cp) at multiple chordwise locations and comparing those values to CFD results.

This is not intended to be a permanent instrumentation system. The goal is to create a simple, functional setup that can collect useful validation data for one nominal aero configuration.

The final deliverable is a plot of measured Cp vs chordwise location (x/c) overlaid with CFD Cp at the same locations. Optional additional outputs include velocity vs time and pressure vs time, but these are secondary.

---

## **Measurement Concept**

The system uses two identical differential pressure sensors (4525DO-based).

Because only two sensors are available:

* One sensor will be used continuously as a pitot-static sensor to measure freestream dynamic pressure and velocity  
* One sensor will be used to measure one surface pressure tap at a time

To obtain a full Cp distribution:

* Approximately 5 chordwise tap locations will be defined  
* Each tap will be tested in separate runs  
* Data from all runs will be combined to form Cp vs x/c

This is strictly a chordwise study, not spanwise.

---

## **Hardware**

Sensors:

* 2x Pixhawk digital differential airspeed sensor kits (4525DO, 1 psi range)

Controller:

* ESP32 Feather V2

Other components (to be finalized):

* Pitot-static tube (included with kit)  
* Pressure tap tubing (additional tubing likely needed)  
* Onboard data logging hardware (to be selected)  
* Electronics enclosure (planned in endplate region)

---

## **Measurement Architecture**

### **Pitot Sensor**

One sensor is dedicated to the pitot-static tube.

It measures dynamic pressure:

q∞ \= Pt − P∞

Velocity is computed as:

V \= sqrt(2q∞ / ρ)

This sensor provides the denominator for Cp calculation.

### **Surface Pressure Sensor**

The second sensor measures pressure at one C-channel tap location.

It measures:

P\_surface − P∞

This is done by connecting:

* One port to the pressure tap  
* One port to a static reference

### **Cp Calculation**

Cp is calculated as:

Cp \= (P\_surface − P∞) / q∞

Dynamic pressure comes directly from the pitot sensor, so velocity does not need to be explicitly used unless desired for reporting.

---

## **Static Reference Strategy**

The current plan is to use the static port from the pitot-static tube as the reference pressure for the surface pressure sensor.

This keeps all measurements referenced to the same static pressure source and simplifies the setup.

Note:  
 If the pitot tube is placed in disturbed flow near the endplate, the static pressure may be slightly biased. However, for this quick validation system, this approach is acceptable and recommended.

---

## **Pressure Tap Plan**

* Approximately 5 pressure taps will be placed along the chord of the C-channel  
* All taps will be on the bottom surface  
* Only one tap will be connected at a time  
* Each tap corresponds to a specific x/c location from CFD

Tap locations must be selected from CFD and documented before testing.

Final plots should use nondimensional chordwise position (x/c).

---

## **Test Conditions**

* Straight-line runs only  
* Single aero configuration  
* Static ride height (no sweep)  
* Target speed up to \~45 mph  
* CFD reference condition is 20 m/s

No multi-condition testing is required.

---

## **Data Logging Requirements**

The system should log the following:

* Timestamp  
* Pitot differential pressure  
* Surface pressure differential  
* Calculated velocity  
* Calculated Cp  
* Tap location identifier

Important:  
 Both raw pressure data and processed values must be saved.

---

## **Mechanical Packaging**

A compact enclosure should be designed and mounted in or near the endplate to house:

* ESP32  
* Pressure sensors  
* Wiring  
* Logging hardware

This helps:

* Protect components  
* Reduce tubing/wiring length  
* Improve robustness during testing

The pitot tube will be mounted forward of the endplate and routed back to the enclosure.

Mounting can be simple (3D printed brackets, zip ties, tape) but must be secure enough for test runs.

---

## **Test Procedure**

1. Select one tap location  
2. Connect tubing from tap to surface pressure sensor  
3. Mount pitot tube facing freestream  
4. Install enclosure and electronics  
5. Perform straight-line run up to target speed  
6. Log all data onboard  
7. Repeat run if needed  
8. Move to next tap location  
9. Repeat until all taps are tested

---

## **Data Processing**

For each run:

* Identify steady-speed segment  
* Average pitot pressure over that segment  
* Average surface pressure over that segment  
* Compute average Cp for that tap

Final output:

* Plot Cp vs x/c  
* Overlay CFD Cp

Optional:

* Velocity vs time  
* Pressure vs time

---

## **Known Limitations**

* Only one tap measured per run  
* Possible vibration noise in data  
* Static reference may not be perfectly freestream  
* Temporary mounting and packaging  
* Limited testing conditions

---

## **Tasks to be Completed**

Electronics:

* Determine wiring and communication for 4525DO sensors with ESP32  
* Ensure both sensors can be read simultaneously  
* Implement sensor reading code

Logging:

* Select and integrate onboard logging (likely SD card)  
* Define data format (CSV recommended)

Tap Design:

* Select 5 chordwise locations from CFD  
* Choose tap hole size (\~0.5–1.0 mm recommended)  
* Design tubing connections

Mechanical:

* Design pitot mount  
* Design electronics enclosure in endplate  
* Route tubing and wiring  
* Secure all components

Testing:

* Bench test sensors  
* Verify sign conventions  
* Perform on-car runs  
* Collect data

Post-Processing:

* Extract data  
* Compute Cp  
* Generate Cp vs x/c plot  
* Compare with CFD

---


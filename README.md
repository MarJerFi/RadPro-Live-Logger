# RadPro Live Logger (Windows)

A lightweight, standalone Windows desktop application for real-time radiation monitoring, charting, and CSV data logging from Geiger counters running the open-source **RadPro** firmware (such as FNIRSI GC-01, FNIRSI GC-03, Bosean FS-600/FS-1000, etc.).

Built with **Lazarus IDE / Free Pascal** — compiles into a single native `.exe` (~3–4 MB) with zero external runtime dependencies (no Python or .NET installation required).

Last release: https://github.com/MarJerFi/RadPro-Live-Logger/releases/download/v0.1/radpro_live_logger.exe

<img width="730" height="592" alt="screenshot" src="https://github.com/user-attachments/assets/ead6e628-89ba-4c1a-90d8-e526d6dbe632" />
---

## Common Geiger Tube Conversion Factors (`CPM / uSv/h`)

Upon connecting, this application automatically reads the configured sensitivity factor directly from your RadPro device (`GET tubeSensitivity`). For reference, here are the official default values calibrated for a standard **Cs-137** gamma source in **RadPro 3.1+**:

| Geiger Tube Model | Common Devices | RadPro Default Factor (`CPM / uSv/h`) |
| :--- | :--- | :---: |
| **M4011 / J321** | FNIRSI GC-01, FNIRSI GC-03, Bosean FS-600 / FS-1000 | **108.35** (`108.345`) |
| **J305** | FNIRSI GC-01 (some revisions), GQ GMC-300E / 320 / 500 | **135.20** (`135.200`) |
| **SBM-20 (СБМ20)** | Custom builds, older counters, modified GC-01 | **106.11** (`106.105`) |
| **HH614** | Compact pocket counters | **30.16** (`30.157`) |
| **SI-3BG (СИ3БГ)** | High-range military/civilian dosimeters | **3.27** (`3.267`) |
| **LND 7317** | Pancake probes, GQ GMC-600+ | **252.57** (`252.567`) |

*Note: Older generic documentation online often cites `153.8` for M4011 tubes, which is a legacy approximation. RadPro uses `108.345` based on precise Cs-137 physical simulations.*

---

## Features

* **Real-Time Monitoring:** Displays live radiation rate in **CPM** and dose rate in **µSv/h**, plus device battery voltage.
* **Auto-Calibration:** Automatically queries the Geiger tube sensitivity factor (`GET tubeSensitivity`) from the device upon connection, with an option to manually override it in the UI.
* **Live Chart:** Real-time scrolling graph (`TAChart`) with vertical date/time labels on the X-axis.
* **Flexible Polling Intervals:** Configurable sampling intervals ranging from **0.5 seconds** up to **1 hour**.
* **RAM Buffer & CSV Export:** Stores up to **100,000 records** in memory (~27 hours at 1s interval) for on-demand CSV export, or supports continuous real-time auto-saving to a user-selected CSV file.
* **Native Dark Mode:** Automatically adapts to Windows 10/11 Light or Dark theme.

---

## How to Use (End Users)

1. **Enable USB Data on your Geiger Counter:**
   * On your device running RadPro, go to **Settings -> Data mode** and set it to **On**.
   * Connect the counter to your PC via a USB data cable.
2. **Connect in the Application:**
   * Launch the `.exe` file.
   * Select the detected **COM port** from the dropdown list (click **Refresh Ports** if plugged in after launch).
   * Choose your desired polling interval and click **Connect**.
3. **Logging Data:**
   * Check **Auto-save to CSV file** (and optionally choose a custom file path via **Select CSV File...**) for continuous disk logging.
   * Alternatively, leave auto-save unchecked to collect data in the RAM buffer and click **Save Buffer to CSV** when finished.

---

## Building from Source (Lazarus IDE)

If you want to modify or compile the source code yourself using **Lazarus IDE** (English interface):

### 1. Required Packages
Install the following two packages via **Package -> Online Package Manager**:
1. **`LazSerial`** (for RS232 / USB CDC serial communication)
2. **`MetaDarkStyle`** (for native Windows 10/11 Dark Mode support)

After installing, ensure both packages are added to your project dependencies:
* Go to **Project -> Project Inspector -> Add -> New Requirement** and add **`LazSerial`** and **`MetaDarkStyle`** (alongside the default `TAChartLazarusPkg` and `LCL`).

### 2. Form Components & Object Inspector Setup (`Form1`)
If you are recreating or modifying the form layout, verify these key properties in the **Object Inspector**:

* **`LazSerial1` (`TLazSerial`):**
  * `BaudRate`: `br115200`
  * `DataBits`: `db8bits`
  * `Parity`: `pNone`
  * `StopBits`: `sbOne`
  * *Events:* `OnRxData` -> `LazSerial1RxData`
* **`Timer1` (`TTimer`):**
  * `Enabled`: `False`
  * `Interval`: `1000`
  * *Events:* `OnTimer` -> `Timer1Timer`
* **`ListChartSource1` (`TListChartSource`):**
  * Placed on `Form1` to store chart points and timestamps.
* **`Chart1` (`TChart`) & `Chart1LineSeries1` (`TLineSeries`):**
  * `Chart1LineSeries1.Source` -> `ListChartSource1`
  * `Chart1.BottomAxis.Marks.Source` -> `ListChartSource1`
  * `Chart1.BottomAxis.Marks.Style` -> `smsLabel`
  * `Chart1.BottomAxis.Marks.LabelFont.Orientation` -> `900` (90 degrees vertical)
  * `Chart1.LeftAxis.Marks.Style` -> `smsValue` (leave `LeftAxis` defaults untouched)
* **`SaveDialog1` (`TSaveDialog`):**
  * `DefaultExt`: `csv`
  * `Filter`: `CSV files (*.csv)|*.csv`
* **Form & Controls Events:**
  * `Form1`: `OnCreate` -> `FormCreate`, `OnClose` -> `FormClose`
  * `ComboBoxInterval`: `OnChange` -> `ComboBoxIntervalChange`
  * Buttons (`ButtonConnect`, `ButtonRefresh`, `ButtonSelectFile`, `ButtonSaveBuffer`, `ButtonClearBuffer`): assign their respective `OnClick` handlers.

### 3. Compiling a Clean Release Executable
To build a small standalone `.exe` (~3–4 MB) without debug symbols:
1. Go to **Project -> Project Options -> Compiler Options -> Debugging**.
2. Uncheck **Generate info for the debugger**.
3. Press **Ctrl + F9** (or **Run -> Build**).

---

## License
Open-source software. Free to use, modify, and distribute. Compatible with the [RadPro](https://github.com/Gissio/radpro) communication protocol.

# Host Card Emulation (HCE) Phone-to-Phone NFC Feasibility Validator

This repository contains a lightweight, Android-native validator application built using Flutter. The goal of this project is to characterize and validate the feasibility of **Phone-to-Phone Host Card Emulation (HCE)**. 

While HCE is a standard Android OS capability powering applications like Google Wallet, it is historically verified in phone-to-fixed-terminal configurations. This validator provides a clean, instrumented test harness to verify physical-layer reliability, data integrity, and connection stability when two consumer mobile devices communicate directly over NFC.

---

## 🏗️ Architecture & Mechanism

The application utilizes two distinct execution roles compiled into a single codebase and selectable at runtime:

1. **Emitter Mode**: Makes the host device present itself to external readers as an NFC Forum Type 4 Tag, emulating a contactless card in software.
2. **Reader Mode**: Runs an active NFC session utilizing the ISO-DEP (ISO/IEC 14443-4) protocol to negotiate connection parameters, read the emulated NDEF records, and perform content validation.

### Android OS Configuration
To enable HCE on the Android platform, the system relies on the following configurations:
- **`AndroidManifest.xml`**: Declares NFC permission/hardware features, BIND permissions, and registers the Host APDU Service wrapper (`com.novice.flutter_nfc_hce.KHostApduService`).
- **`apduservice.xml`**: Registers the standard NFC Forum Type 4 Tag NDEF Application Application Identifier (AID): **`D2760000850101`**. All matching select commands from the reader are automatically routed by the OS kernel to the service.

---

## 🛠️ Requirements & Setup

### Environment Requirements
- **Flutter SDK**: Stable channel, version `3.41.9` or compatible.
- **Android SDK**: Compile SDK 33 / Target SDK 33 (requires physical hardware running Android API level 19+). 
*Note: NFC HCE emulation and active reader polling cannot be simulated on Android virtual emulators; physical hardware is required.*

### Setup Instructions
1. Clone the repository and change directory:
   ```bash
   git clone <repository-url>
   cd "HCE Idea Validation"
   ```
2. Retrieve the required Flutter packages:
   ```bash
   flutter pub get
   ```
3. Enable **USB Debugging** on your target Android devices (located under system Developer Options).
4. Verify the devices are connected to your host machine:
   ```bash
   flutter devices
   ```
5. Deploy and execute the application:
   ```bash
   flutter run
   ```

---

## 📱 Simulation Flow (Step-by-Step)

To simulate and test the feasibility flow, you will need two physical Android devices running the application:

```
                  ┌────────────────────────┐
                  │   Select Feasibility   │
                  │          Role          │
                  └───────────┬────────────┘
                              │
             ┌────────────────┴────────────────┐
             ▼                                 ▼
     [ Emitter Mode ]                  [ Reader Mode ]
     (Phone A - Card)                  (Phone B - Reader)
             │                                 │
             ▼                                 ▼
   "Start Broadcasting"                "Start Listening"
             │                                 │
             └────────────────┬────────────────┘
                              ▼
                     Touch Backs of Phones
                              │
                              ▼
                   Reader Logs PASS/FAIL
```

### 1. Configure the Emitter (Device A)
- Launch the application and select **Emitter Mode**.
- Ensure the hardware status displays **READY**. (If NFC is disabled at the OS level, navigate to system settings to enable it).
- Press the **Start Broadcasting** button. The state indicator will change to **BROADCASTING**.
- The device is now active and ready to transmit the hardcoded payload constant: `HELLO_FROM_PHONE_A`.

### 2. Configure the Reader (Device B)
- Launch the application and select **Reader Mode**.
- Press the **Start Listening** button. The state indicator will change to **LISTENING**.

### 3. Establish NFC Connection
- Touch the backs of Device A and Device B together. The NFC antennas are typically located near the center back plate or the camera module.
- Keep the devices in close proximity. The active reader (Device B) will scan the emulated tag, extract the payload verbatim, compare it against the expected test payload, and log a **PASS** or **FAIL** entry in the scrolling log panel with a precise timestamp.

---

## ⚠️ Limitations & Diagnostics

- **Startup Class Warnings (NullPointerException)**:
  During class instantiation on HCE activation, you may observe a `java.lang.NullPointerException` in your console logs. This occurs because the plugin attempts to access the file system within the constructor before the Android service `Context` is officially attached. Once `onStartCommand()` is executed by the OS, the context binds, and the service writes and emulates the NDEF payload correctly. This exception does not impact execution and can be ignored.
- **State Mounted Checks**:
  To prevent runtime application instability when navigating between screens during active transactions, all asynchronous state-mutations in the main entry point code are guarded with widget `mounted` checks.

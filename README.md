# Host Card Emulation (HCE) Phone-to-Phone NFC Feasibility Validator

This repository contains a lightweight, Android-native validator application built using Flutter, paired with a Python FastAPI backend server. The goal of this project is to characterize, instrument, and validate the feasibility of **Phone-to-Phone Host Card Emulation (HCE)**.

While HCE is a standard Android capability used widely in mobile payment systems (e.g., Google Wallet) to talk to fixed POS terminals, using HCE for direct phone-to-phone communication is less common and presents unique physical and software constraints. This project serves as an end-to-end test harness to verify physical-layer reliability, connection stability, location tagging, and backend transaction reporting.

---

## 📌 Context: What is Happening Now & Why (Iteration 2)

This project has evolved from a simple static verification tool into a dynamic transactional validation prototype.

### What is Happening Now (Iteration 2)
In the current phase, we are moving beyond simple connection checks. We have upgraded the system to:
1. **Accept Variable User Inputs**: The Emitter client now features an interactive text input to broadcast arbitrary user payloads dynamically.
2. **Tag Transactions with Geolocation**: Upon a successful NFC read, the Reader client captures its high-accuracy GPS coordinates (a one-time position fix).
3. **Dispatch Transaction Reports**: The Reader POSTs the transaction payload, GPS coordinates, and timestamp to a local FastAPI backend.
4. **Trigger Out-of-Band Email Receipts**: The backend processes reports and sends real-time email alerts via the **Resend API** containing a clickable Google Maps link to the transaction location.

### Why This is Happening
- **Protocol & Payload Framing Limits**: Spike 1 used a hardcoded constant (`HELLO_FROM_PHONE_A`) to verify that the NFC channel worked without risk of typos. However, a fixed string does not guarantee that the APDU-level framing will handle variable-length payloads cleanly. Testing user-entered inputs verifies that the underlying APDU packetization handles arbitrary data correctly.
- **Location Verification**: In local transaction flows, proving *where* a transaction took place is critical for fraud prevention and audits. Capturing a one-shot GPS fix at the moment of NFC contact validates that mobile clients can retrieve high-accuracy location metadata and attach it directly to transaction packets.
- **Out-of-Band Verification**: From a testing methodology standpoint, log printouts on the devices can be misleading (susceptible to false positives). An email landing in a real inbox is a verification step external to the devices and the server. If a physical email arrives containing the correct coordinates and custom payload, it acts as definitive proof that the entire chain—from physical NFC tap to backend processing—is reliable and fully functioning.

---

## 🏗️ System Architecture & Layout

The project is organized as a monorepo consisting of two independently deployable units:

```text
/ (repository root)
├── android/            # Native Android configuration files
├── lib/                # Flutter client source code (main.dart)
├── server/             # FastAPI backend (main.py, services/mailer.py)
├── pubspec.yaml        # Flutter dependencies list
├── NOTES.md            # Hardware setup and local validation logs
└── README.md           # This file
```

### 📱 1. Flutter Client Application
The mobile client can be launched in one of two runtime roles:
- **Emitter Role**: Configures the phone to act as an HCE card. It uses the `flutter_nfc_hce` plugin to bind to the Android system's Host APDU Service, emulating an NFC Forum Type 4 NDEF Tag.
- **Reader Role**: Actively polls for tags using `nfc_manager` (locked to `v3.3.0` to preserve the NDEF parsing APIs). Once decoded, it invokes the `geolocator` library for location capture and `http` to post telemetry to the backend.

### 🖥️ 2. FastAPI Backend Server
A minimal REST API built with FastAPI:
- Exposes `POST /transaction-report` to receive, validate (Pydantic), and process transaction events.
- Utilizes the `resend` Python client to generate structured monospaced HTML emails summarizing transactions.

---

## 📱 Physical Simulation Flow (Step-by-Step)

Testing phone-to-phone HCE requires two physical Android devices (emulators cannot bind to hardware NFC controllers or simulate location services accurately).

```
       [ Emitter (Phone A) ]                    [ Reader (Phone B) ]
   ┌───────────────────────────┐            ┌───────────────────────────┐
   │ Enter Variable Payload    │            │ Ensure GPS is Active      │
   │ (e.g., "TRANSACTION_99")  │            │                           │
   └─────────────┬─────────────┘            └─────────────┬─────────────┘
                 │                                        │
                 ▼                                        ▼
         Start Broadcasting                        Start Listening
                 │                                        │
                 └───────────────┬────────────────────────┘
                                 ▼
                       Touch Backs of Phones
                                 │
                                 ▼
                     Payload Decoded on Reader
                                 │
                                 ▼
                     GPS Coordinates Captured (One-shot)
                                 │
                                 ▼
                     HTTPS POST to FastAPI Server
                                 │
                                 ▼
                    Email Dispatched via Resend SDK
```

1. **Start the Emitter (Device A)**:
   - Open the app and tap **Emitter Mode**.
   - Input your custom text payload. Empty payloads are rejected client-side.
   - Tap **Start Broadcasting** (status turns to `BROADCASTING`).
2. **Start the Reader (Device B)**:
   - Open the app and tap **Reader Mode**.
   - Tap **Start Listening** (status turns to `LISTENING`).
3. **Execute NFC Transmission**:
   - Align the NFC antennas of both devices back-to-back (usually near the top camera module).
   - Once Phone B reads and parses the payload:
     - It requests location permissions (if not already granted).
     - It queries a high-accuracy GPS fix.
     - It POSTs the JSON payload to the FastAPI server.
     - The reporting status indicator updates to `REPORT SUCCESS: Email Sent`.
4. **Out-of-Band Receipt**:
   - Open the registered recipient inbox to verify that the Resend HTML alert containing the custom payload and active Google Maps link has arrived.

---

## 🛠️ Setup & Running Instructions

### Client Setup
1. Fetch dependencies:
   ```bash
   flutter pub get
   ```
2. Open `lib/main.dart` and locate the `backendBaseUrl` constant near the top of the file. Update it to your backend machine's local LAN IP address (e.g., `http://192.168.1.120:8000`).
3. Connect your Android devices via USB, enable **USB Debugging** in Developer Options, and run:
   ```bash
   flutter run
   ```

### Backend Setup
For server configurations, runtime dependencies, and testing endpoints, refer to the [Server Documentation](server/README.md).

---

## ⚠️ Limitations & Diagnostics

- **Background HCE Limitation**: The card emulation background service does not expose read-completion lifecycle events back to the Dart UI layer. As a result, the Emitter's session read counter will remain at `0`.
- **CORS & Local Network Routing**: Physical mobile clients cannot resolve `localhost` or `127.0.0.1` to reach a server running on your development machine. The devices must be connected to the same Wi-Fi network, and the machine's actual LAN IP must be specified in the client code.
- **Location Timeout**: If the Reader device has difficulty getting a GPS lock (e.g., indoors), the request will time out after 10 seconds to prevent app lockups, falling back to an error state.
- **Linter Errors**: You may see a temporary `Cannot find module 'resend'` warning in the editor if your global IDE environment does not match your active python virtual environment path. This does not affect execution.

# NFC HCE Feasibility Validator Notes - Iteration 2

This file details the technical configurations, package choices, native resource modifications, limitations, and instructions for running the phone-to-phone Host Card Emulation validation with GPS location tracking and server-confirmed email reporting.

---

## 1. Selected Flutter Packages & Versions

The following plugins are used for NFC capabilities, location capture, and networking:
1. **`flutter_nfc_hce` (v0.1.8)**: Used for emulating an NFC Forum Type 4 contactless card (Host Card Emulation).
2. **`nfc_manager` (v3.3.0)**: Used on the reader device to start an NFC session, detect external tags, and parse/log NDEF payloads. Locked to `v3.3.0` because version 4.x introduces breaking changes that split NDEF types into a separate package.
3. **`geolocator` (v14.0.3)**: Used to capture high-accuracy GPS coordinates of the Reader device during a transaction.
4. **`http` (v1.6.0)**: Used to post the transaction payload and GPS metadata to the backend endpoint.

---

## 2. Native Android Modifications

To support NFC card emulation and location tracking on Android, the following native configurations are declared:

### A. Manifest Permissions & Services (`android/app/src/main/AndroidManifest.xml`)
- Declared the following permissions and hardware features:
  ```xml
  <uses-permission android:name="android.permission.NFC" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-feature android:name="android.hardware.nfc" android:required="false" />
  <uses-feature android:name="android.hardware.nfc.hce" android:required="false" />
  ```
- Registered the native `KHostApduService` inside the `<application>` element to handle HOST APDU service routing:
  ```xml
  <service
      android:name="com.novice.flutter_nfc_hce.KHostApduService"
      android:exported="true"
      android:enabled="true"
      android:permission="android.permission.BIND_NFC_SERVICE">
      <intent-filter>
          <action android:name="android.nfc.cardemulation.action.HOST_APDU_SERVICE" />
          <category android:name="android.intent.category.DEFAULT" />
      </intent-filter>
      <meta-data
          android:name="android.nfc.cardemulation.host_apdu_service"
          android:resource="@xml/apduservice" />
  </service>
  ```

### B. AID Filtering Config (`android/app/src/main/res/xml/apduservice.xml`)
- Maps SELECT command routing for the standard NFC Type 4 NDEF Application AID `D2760000850101`:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
      android:description="@string/servicedesc"
      android:requireDeviceUnlock="false">
      <aid-group android:description="@string/aiddescription"
          android:category="other">
          <aid-filter android:name="D2760000850101"/> 
      </aid-group>
      </host-apdu-service>
  ```

### C. Resource Metadata Strings (`android/app/src/main/res/values/strings.xml`)
- System settings string labels mapping HCE service descriptors:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <resources>
      <string name="servicedesc">HCE Feasibility Service</string>
      <string name="aiddescription">AID for HCE Feasibility Test</string>
  </resources>
  ```

---

## 3. Backend Service Architecture (`/server/`)

The backend is built with FastAPI to receive transaction reports and dispatch real-time email alerts.

- **FastAPI Endpoint (`POST /transaction-report`)**:
  - Accept JSON payload containing `payload` (variable text string), `latitude` (float), `longitude` (float), and `timestamp` (ISO 8601 string).
  - Validates parameters via Pydantic model schemas.
  - CORS middleware configured permissively (`allow_origins=["*"]`) to allow local network requests from physical mobile devices.
- **Mailer Service (`services/mailer.py`)**:
  - Integrates the official Resend Python SDK (`import resend`).
  - Formats email payloads utilizing an editorial technical monospaced HTML table layout.
  - Dynamically builds Google Maps coordinate links (`https://www.google.com/maps?q=<lat>,<lng>`).
- **Configuration (`.env` file)**:
  - `RESEND_API_KEY`: Verified API token.
  - `RESEND_SENDER_EMAIL`: Custom verified sending domain sender address (e.g. `sender@yourverifieddomain.com`).
  - `REPORT_RECIPIENT_EMAIL`: Target address for transaction receipt reports.

---

## 4. Discovered Limitations & Constraints

During Iteration 2 implementation, the following limits were identified:
1. **Emitter Read Confirmation**: The `flutter_nfc_hce` plugin runs as a background service and does not trigger dynamic Dart callbacks when a Reader reads its payload. Emitter session counters remain at `0` (a notice is shown on the Emitter screen).
2. **GPS Fix Dependency**: Retrieving GPS location on the Reader device requires device hardware GPS receivers to be enabled and location permissions granted. A timeout of 10 seconds is configured to prevent transaction freezes in low signal environments.
3. **CORS/LAN Testing**: Physical Android devices cannot resolve `127.0.0.1` or `localhost` to hit a backend hosted on a development machine. Testing requires the backend machine's LAN IP address (e.g., `http://192.168.1.100:8000`) to be defined under `backendBaseUrl` in the Flutter code.
4. **Email Dispatch Authentication**: Resend enforces verification of the sender domain or API keys. Sending emails will fail unless the server runs with a verified sending domain and valid API token.

---

## 5. Verification & Running Instructions

### A. Run the Backend Server
1. Navigate to `/server/`:
   ```bash
   cd server
   ```
2. Set up a virtual environment (optional but recommended):
   ```bash
   python -m venv venv
   .\venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure env variables:
   Copy `.env.example` to `.env` and fill in active Resend credentials.
5. Start Uvicorn:
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

### B. Compile and Deploy the Flutter Application
1. Verify the `backendBaseUrl` constant near the top of `lib/main.dart` points to your machine's LAN IP address.
2. Build the APK:
   ```bash
   flutter build apk --release
   ```
3. Install on two NFC-capable physical Android devices.
4. Open the Emitter mode app on Phone A:
   - Type a custom payload message (e.g. `VALIDATION_TEST_123`).
   - Start Broadcasting.
5. Open the Reader mode app on Phone B:
   - Ensure Location Services are turned on.
   - Start Listening.
6. Align Phone A and Phone B together:
   - Phone B reads the custom payload.
   - GPS permission is requested on Phone B, location is captured.
   - Phone B sends the POST request to the backend.
   - The transaction report status updates to `REPORT SUCCESS: Email Sent`.
   - Verify recipient email contains the correct payload, timestamp, and a working Google Maps link to Phone B's coordinates.

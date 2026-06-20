# NFC HCE Feasibility Validator Notes

This file details the technical configurations, package choices, native resource modifications, limitations, and instructions for running the phone-to-phone Host Card Emulation validation.

---

## 1. Selected Flutter Packages & Versions

The following plugins have been added to the project for NFC capabilities:
1. **`flutter_nfc_hce` (v0.1.8)**: Used for emulating an NFC Forum Type 4 contactless card (Host Card Emulation).
2. **`nfc_manager` (v4.2.1)**: Used on the reader device to start an NFC session, detect external tags, and parse/log raw NDEF payload arrays over the ISO-DEP protocol.

---

## 2. Native Android Modifications

To support Host Card Emulation at the Android OS layer, the following files were manually updated or created:

### A. Manifest Permissions & Service (`android/app/src/main/AndroidManifest.xml`)
- Added NFC permission and hardware features to ensure the OS compiles the app with NFC hardware compatibility:
  ```xml
  <uses-permission android:name="android.permission.NFC" />
  <uses-feature android:name="android.hardware.nfc" android:required="false" />
  <uses-feature android:name="android.hardware.nfc.hce" android:required="false" />
  ```
- Registered the native `KHostApduService` (exposed by the HCE plugin) inside the `<application>` element. This routes BIND intents matching the HCE host APDU protocol to our service:
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
- Configured the system's Host APDU service selector to trigger on the standard NFC Forum Type 4 NDEF Application AID `D2760000850101`. This allows the reader to invoke our emulated tag application directly:
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
- Defined string descriptions for the Android system settings interface detailing our custom HCE service:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <resources>
      <string name="servicedesc">HCE Feasibility Service</string>
      <string name="aiddescription">AID for HCE Feasibility Test</string>
  </resources>
  ```

---

## 3. Discovered Limitations & Constraints

During design and implementation, the following package-specific behaviors and platform limitations were identified:
1. **Lack of Read Confirmation Callback (Emitter)**: The `flutter_nfc_hce` plugin runs the underlying card emulation as a background service and does not trigger dynamic Dart-level callback hooks when a reader successfully pulls the NDEF payload. As a result, the success counter on the Emitter screen is restricted to `0` and a notice has been added to the UI to state this honestly.
2. **AID Customization**: The `flutter_nfc_hce` Java/Kotlin library hardcodes the response bytes matching SELECT commands for `D2760000850101`. Emulating custom non-NDEF AIDs is not supported directly without rewriting the plugin's native code.
3. **Android API Floor**: Host Card Emulation requires a minimum of Android API level 19 (KitKat 4.4). `nfc_manager` recommends setting compile and target SDKs appropriately.
4. **Physical Device Dependency**: Emulators cannot bind to hardware NFC controllers. Testing requires physical Android hardware.

---

## 4. Installation & Verification Instructions

Follow these steps to compile and verify phone-to-phone operation:

1. **Prerequisites**: Ensure Flutter is installed and two physical Android devices with NFC are connected via ADB (or install the output APK manually).
2. **Build the APK**:
   ```bash
   flutter build apk --release
   ```
3. **Deploy the Single APK**:
   Install the identical APK file `build/app/outputs/flutter-apk/app-release.apk` on **both** test devices:
   ```bash
   adb -s <DEVICE_1_ID> install build/app/outputs/flutter-apk/app-release.apk
   adb -s <DEVICE_2_ID> install build/app/outputs/flutter-apk/app-release.apk
   ```
4. **Verify Phone A (Emitter)**:
   - Launch the application, choose **Emitter Mode**.
   - Ensure hardware status displays "READY" (if NFC is disabled, enable it via Android settings).
   - Press **Start Broadcasting** (state changes to "BROADCASTING").
5. **Verify Phone B (Reader)**:
   - Launch the application, choose **Reader Mode**.
   - Press **Start Listening** (state changes to "LISTENING").
6. **Execute Test**:
   - Align the NFC antennas of Phone A and Phone B together (usually back-to-back near the camera module or center back plate).
   - Verify that Phone B reads and displays `HELLO_FROM_PHONE_A` under "VERBATIM PAYLOAD", flags the result as **PASS**, and appends the record to the scrolling log screen with a timestamp.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// HARDCODED TEST PAYLOAD (Section 4.2 / 4.3 Requirement)
const String testPayload = "HELLO_FROM_PHONE_A";

// Iteration 2: FastAPI Backend Base URL
const String backendBaseUrl = "http://10.0.2.2:8000"; // Default loopback for Android emulator/LAN

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HCE NFC Validator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A1A1A),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFDD2200),
        ),
        fontFamily: 'monospace', // Monospaced font for editorial/technical feel
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const ModeSelectorScreen(),
    );
  }
}

// ----------------------------------------------------
// 1. MODE SELECTION SCREEN (App Entry Point)
// ----------------------------------------------------
class ModeSelectorScreen extends StatelessWidget {
  const ModeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC VALIDATOR V1.0'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Text(
              'SELECT FEASIBILITY ROLE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // EMITTER MODE CARD
            _buildRoleButton(
              context,
              title: 'EMITTER MODE',
              description: 'Configure this device to act as an HCE contactless card and broadcast the test payload.',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmitterScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            // READER MODE CARD
            _buildRoleButton(
              context,
              title: 'READER MODE',
              description: 'Configure this device to scan for ISO-DEP NFC tags and record incoming payload logs.',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReaderScreen()),
                );
              },
            ),
            const Spacer(),
            const Text(
              'INTERNAL USE ONLY • FEASIBILITY SPIKE',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF888888),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, {
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2.0),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 2. EMITTER MODE SCREEN
// ----------------------------------------------------
class EmitterScreen extends StatefulWidget {
  const EmitterScreen({super.key});

  @override
  State<EmitterScreen> createState() => _EmitterScreenState();
}

class _EmitterScreenState extends State<EmitterScreen> {
  final _hcePlugin = FlutterNfcHce();
  final TextEditingController _payloadController = TextEditingController(text: "HELLO_FROM_PHONE_A");
  bool _isBroadcasting = false;
  String _hardwareStatus = "Checking...";
  String _errorLog = "";
  int _successReads = 0; // Session read counter

  @override
  void initState() {
    super.initState();
    _checkHardware();
  }

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  Future<void> _checkHardware() async {
    try {
      bool isSupported = await _hcePlugin.isNfcHceSupported();
      bool isEnabled = await _hcePlugin.isNfcEnabled();

      if (!mounted) return;
      setState(() {
        if (!isSupported) {
          _hardwareStatus = "LACKS HCE SUPPORT";
        } else if (!isEnabled) {
          _hardwareStatus = "NFC DISABLED IN SETTINGS";
        } else {
          _hardwareStatus = "READY";
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hardwareStatus = "ERROR CHECKING HARDWARE";
        _errorLog = e.toString();
      });
    }
  }

  Future<void> _toggleBroadcasting() async {
    if (_isBroadcasting) {
      // STOP
      try {
        await _hcePlugin.stopNfcHce();
        if (!mounted) return;
        setState(() {
          _isBroadcasting = false;
          _errorLog = "";
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorLog = "Stop Error: $e";
        });
      }
    } else {
      // START
      final String textToBroadcast = _payloadController.text.trim();
      if (textToBroadcast.isEmpty) {
        setState(() {
          _errorLog = "Enter text before broadcasting";
        });
        return;
      }

      // Verify hardware state first
      await _checkHardware();
      if (!mounted) return;
      if (_hardwareStatus != "READY") {
        setState(() {
          _errorLog = "Cannot start: hardware state is $_hardwareStatus";
        });
        return;
      }

      try {
        var result = await _hcePlugin.startNfcHce(
          textToBroadcast,
          mimeType: 'text/plain',
          persistMessage: true,
        );
        if (!mounted) return;
        setState(() {
          _isBroadcasting = true;
          _errorLog = result != null && result.contains("success") ? "" : "HCE Output: $result";
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorLog = "Start Error: $e";
          _isBroadcasting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isReady = _hardwareStatus == "READY";

    return Scaffold(
      appBar: AppBar(
        title: const Text('EMITTER CONTROL'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Mode Header
            const Text(
              'ROLE: EMITTER',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 24),
            // Hardware Status Warning Box
            if (!isReady)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDD2200), width: 2.0),
                  color: const Color(0xFFFFF0F0),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARDWARE WARNING: $_hardwareStatus',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDD2200),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please verify NFC is enabled in System Settings and that your device supports Host Card Emulation.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF882222)),
                    ),
                  ],
                ),
              ),

            // Variable Payload Input Field
            TextField(
              controller: _payloadController,
              enabled: !_isBroadcasting,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              decoration: const InputDecoration(
                labelText: 'BROADCAST PAYLOAD',
                labelStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF888888),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 2.0),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                ),
                filled: true,
                fillColor: Color(0xFFF9F9F9),
              ),
            ),
            const SizedBox(height: 32),

            // Large State Label
            Center(
              child: Column(
                children: [
                  const Text(
                    'BROADCAST STATE',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isBroadcasting ? 'BROADCASTING' : 'IDLE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isBroadcasting ? const Color(0xFF00AA55) : const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Primary Toggle Button
            ElevatedButton(
              onPressed: _toggleBroadcasting,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBroadcasting ? const Color(0xFFDD2200) : const Color(0xFF1A1A1A),
                foregroundColor: const Color(0xFFFFFFFF),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, // Sharp edges
                ),
              ),
              child: Text(
                _isBroadcasting ? 'STOP BROADCASTING' : 'START BROADCASTING',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),

            // Session Reads Counter (Section 4.2 constraint details)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SESSION READS COUNTER',
                          style: TextStyle(fontSize: 10, color: Color(0xFF888888)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_successReads (Callback Limitation*)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _successReads = 0;
                      });
                    },
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A)),
                    child: const Text('RESET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '* Note: The flutter_nfc_hce plugin runs the card emulator in a background OS service without exposing a read-completion callback. Therefore, this counter remains zero.',
              style: TextStyle(fontSize: 9, color: Color(0xFF888888), height: 1.3),
            ),

            // Raw Error Panel (Section 4.4 constraint)
            if (_errorLog.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'EXCEPTION LOG',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDD2200)),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDD2200), width: 1.0),
                  color: const Color(0xFFFFF5F5),
                ),
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _errorLog,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFDD2200)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 3. READER MODE SCREEN
// ----------------------------------------------------
class ReaderLogEntry {
  final DateTime timestamp;
  final String content;
  final bool isPass;

  ReaderLogEntry({
    required this.timestamp,
    required this.content,
    required this.isPass,
  });
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _isListening = false;
  String _hardwareStatus = "Checking...";
  String _errorLog = "";
  List<ReaderLogEntry> _logs = [];

  // Iteration 2 states
  String _transactionStatus = "IDLE";
  bool _isReporting = false;

  @override
  void initState() {
    super.initState();
    _checkHardware();
  }

  Future<void> _checkHardware() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() {
        _hardwareStatus = isAvailable ? "READY" : "NFC NOT AVAILABLE / DISABLED";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hardwareStatus = "ERROR CHECKING HARDWARE";
        _errorLog = e.toString();
      });
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    await _checkHardware();
    if (!mounted) return;
    if (_hardwareStatus != "READY") {
      setState(() {
        _errorLog = "Cannot listen: Hardware is $_hardwareStatus";
      });
      return;
    }

    setState(() {
      _isListening = true;
      _errorLog = "";
      _transactionStatus = "LISTENING FOR TAG...";
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          if (!mounted) return;
          String parsedPayload = "";
          bool successfullyDecoded = false;

          // Attempt Ndef extraction first as the standard Type 4 HCE wrapper emulates Ndef
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            try {
              // Read cached or current message
              final message = ndef.cachedMessage ?? await ndef.read();
              for (var record in message.records) {
                parsedPayload = _decodeRecord(record);
                if (parsedPayload.isNotEmpty) {
                  successfullyDecoded = true;
                  break;
                }
              }
            } catch (e) {
              // Ndef read fail fallback
            }
          }

          // Fallback to raw platform data extraction if Ndef wrapper returns empty
          if (!successfullyDecoded) {
            parsedPayload = _extractRawBytes(tag);
          }

          // Empty check validation (Reject immediately)
          if (parsedPayload.isEmpty) {
            setState(() {
              _transactionStatus = "Received empty payload — no transaction recorded";
            });
            return;
          }

          final isPass = parsedPayload == testPayload;
          setState(() {
            _logs.insert(
              0,
              ReaderLogEntry(
                timestamp: DateTime.now(),
                content: parsedPayload,
                isPass: isPass,
              ),
            );
            // Cap log size at 10 items
            if (_logs.length > 10) {
              _logs = _logs.sublist(0, 10);
            }
          });

          // Trigger Location Capture & Transaction Report POST
          _processTransaction(parsedPayload);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorLog = "Start Session Error: $e";
        _isListening = false;
      });
    }
  }

  Future<void> _processTransaction(String payload) async {
    if (_isReporting) return;
    if (!mounted) return;
    setState(() {
      _isReporting = true;
      _transactionStatus = "CAPTURING LOCATION...";
    });

    try {
      // Check location service enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }

      // Check/request runtime permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permission denied by user.");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied.");
      }

      // Get high accuracy current position with settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (!mounted) return;
      setState(() {
        _transactionStatus = "SENDING REPORT...";
      });

      // Send HTTP POST report to backend
      final url = Uri.parse("$backendBaseUrl/transaction-report");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "payload": payload,
          "latitude": position.latitude,
          "longitude": position.longitude,
          "timestamp": DateTime.now().toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _transactionStatus = "REPORT SUCCESS: Email Sent";
          _isReporting = false;
        });
      } else {
        String serverError = "";
        try {
          final bodyJson = jsonDecode(response.body);
          serverError = bodyJson["detail"] ?? response.body;
        } catch (_) {
          serverError = response.body;
        }
        setState(() {
          _transactionStatus = "REPORT FAILED (HTTP ${response.statusCode}): $serverError";
          _isReporting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transactionStatus = "REPORT ERROR: ${e.toString()}";
        _isReporting = false;
      });
    }
  }

  Future<void> _stopListening() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      // Ignore session stop failures
    }
    if (mounted) {
      setState(() {
        _isListening = false;
        _transactionStatus = "IDLE";
      });
    }
  }

  String _decodeRecord(NdefRecord record) {
    try {
      final payload = record.payload;
      if (payload.isEmpty) return "";

      // 1. NFC Well Known Text (TNF = 1, Type = T)
      if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          record.type.length == 1 &&
          record.type[0] == 0x54) { // 'T'
        int status = payload[0];
        int langLen = status & 0x3F;
        if (langLen + 1 <= payload.length) {
          final textBytes = payload.sublist(1 + langLen);
          return utf8.decode(textBytes);
        }
      }

      // 2. MIME Media / Fallback (raw decode)
      final text = utf8.decode(payload, allowMalformed: true);
      // Remove any control symbols
      return text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '').trim();
    } catch (_) {
      return "";
    }
  }

  String _extractRawBytes(NfcTag tag) {
    try {
      // Search for any Ndef/NfcA/IsoDep data in payload maps
      final Map<dynamic, dynamic> tagData = tag.data;
      for (var tech in tagData.keys) {
        final techData = tagData[tech];
        if (techData is Map && techData.containsKey('payload')) {
          final raw = techData['payload'];
          if (raw is List<int>) {
            final text = utf8.decode(raw, allowMalformed: true);
            final cleaned = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '').trim();
            if (cleaned.isNotEmpty) return cleaned;
          }
        }
      }
    } catch (_) {}
    return "";
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isReady = _hardwareStatus == "READY";

    return Scaffold(
      appBar: AppBar(
        title: const Text('READER CONTROL'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Role Header
            const Text(
              'ROLE: READER',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 24),

            // Hardware Status Warning Box
            if (!isReady)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDD2200), width: 2.0),
                  color: const Color(0xFFFFF0F0),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARDWARE WARNING: $_hardwareStatus',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDD2200),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'NFC is turned off or this device lacks NFC capability. Enable it in your system settings to listen.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF882222)),
                    ),
                  ],
                ),
              ),

            // Expected payload comparison reference (just for comparison convenience)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                color: const Color(0xFFF9F9F9),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXPECTED TARGET PAYLOAD',
                          style: TextStyle(fontSize: 10, color: Color(0xFF888888)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          testPayload,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: const Color(0xFF1A1A1A),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Text(
                      'MATCH REF',
                      style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction report status indicator (Iteration 2)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TRANSACTION REPORT STATUS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                    color: const Color(0xFFF9F9F9),
                  ),
                  child: Text(
                    _transactionStatus,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _transactionStatus.contains("SUCCESS")
                          ? const Color(0xFF00AA55)
                          : (_transactionStatus.contains("FAILED") ||
                                  _transactionStatus.contains("ERROR") ||
                                  _transactionStatus.contains("empty"))
                              ? const Color(0xFFDD2200)
                              : const Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scan/Listening State indicator & Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'READER SCAN STATE',
                        style: TextStyle(fontSize: 10, color: Color(0xFF888888)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isListening ? 'LISTENING' : 'NOT LISTENING',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isListening ? const Color(0xFF00AA55) : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _toggleListening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? const Color(0xFFDD2200) : const Color(0xFF1A1A1A),
                    foregroundColor: const Color(0xFFFFFFFF),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: Text(
                    _isListening ? 'STOP' : 'START LISTENING',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Log header and action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DISCOVERED LOGS (MAX 10)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _logs.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: const Color(0xFF1A1A1A),
                  ),
                  child: const Text('CLEAR LOG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Log Panel Scroll Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'NO TAG DATA CAPTURED YET\nBRING EMITTING DEVICE CLOSE',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF888888), height: 1.5),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFF1A1A1A)),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final timeStr = "${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}";
                          return Container(
                            color: log.isPass ? const Color(0xFFF0FFF5) : const Color(0xFFFFF0F0),
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '[$timeStr]',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: log.isPass ? const Color(0xFF00AA55) : const Color(0xFFDD2200)),
                                      ),
                                      child: Text(
                                        log.isPass ? 'PASS' : 'FAIL',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: log.isPass ? const Color(0xFF00AA55) : const Color(0xFFDD2200),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'PAYLOAD: "${log.content}"',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Raw Exception Log (Section 4.4 constraint)
            if (_errorLog.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'EXCEPTION LOG',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDD2200)),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDD2200), width: 1.0),
                  color: const Color(0xFFFFF5F5),
                ),
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _errorLog,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFDD2200)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

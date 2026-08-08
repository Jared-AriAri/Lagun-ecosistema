import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() {
  runApp(const LagunWearApp());
}

class LagunWearApp extends StatelessWidget {
  const LagunWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAGUN Wear',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0712),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.purpleAccent,
          surface: Color(0xFF141024),
        ),
        useMaterial3: true,
      ),
      home: const WatchHomeScreen(),
    );
  }
}

class WatchHomeScreen extends StatefulWidget {
  const WatchHomeScreen({super.key});

  @override
  State<WatchHomeScreen> createState() => _WatchHomeScreenState();
}

class _WatchHomeScreenState extends State<WatchHomeScreen> {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  ServerSocket? _serverSocket;
  final List<Socket> _connectedClients = [];

  bool _isBroadcasting = false;
  bool _isRunning = true;
  int _readingTimeSec = 0;
  int _stressLevel = 0;
  int _sleepQuality = 0;

  Timer? _telemetryTimer;

  @override
  void initState() {
    super.initState();
    _startRealtimeBridgeServer();
    _startTelemetry();
  }

  Future<void> _startRealtimeBridgeServer() async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 7777, shared: true);
      _serverSocket?.listen((Socket client) {
        _connectedClients.add(client);
        client.done.then((_) {
          _connectedClients.remove(client);
        });
      });
    } catch (_) {}
  }

  void _startTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) return;
      setState(() {
        _readingTimeSec += 1;
        _stressLevel = 40 + Random().nextInt(45);
        _sleepQuality = 15 + Random().nextInt(45);
      });

      _broadcastData();
    });
  }

  void _toggleRunning() {
    setState(() {
      _isRunning = !_isRunning;
      if (!_isRunning) {
        _telemetryTimer?.cancel();
        _blePeripheral.stop();
        _isBroadcasting = false;
      } else {
        _startTelemetry();
      }
    });
  }

  Future<void> _broadcastData() async {
    if (!_isRunning) return;

    int safeTime = _readingTimeSec.clamp(0, 65535);
    int safeSleep = _sleepQuality.clamp(0, 255);
    int safeStress = _stressLevel.clamp(0, 255);

    final Uint8List payloadBytes = Uint8List.fromList([
      (safeTime >> 8) & 0xFF,
      safeTime & 0xFF,
      safeSleep,
      safeStress,
    ]);

    for (final client in _connectedClients) {
      try {
        client.add(payloadBytes);
        await client.flush();
      } catch (_) {}
    }

    try {
      final AdvertiseData advertiseData = AdvertiseData(
        includeDeviceName: true,
        serviceUuid: "0000180d-0000-1000-8000-00805f9b34fb",
        manufacturerId: 1234,
        manufacturerData: payloadBytes,
      );

      if (_isBroadcasting) {
        await _blePeripheral.stop();
      }

      await _blePeripheral.start(advertiseData: advertiseData);
      if (mounted && !_isBroadcasting) {
        setState(() => _isBroadcasting = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _blePeripheral.stop();
    for (final client in _connectedClients) {
      client.close();
    }
    _serverSocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _connectedClients.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0712),
      body: Center(
        child: Container(
          width: 224,
          height: 224,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF141024),
            border: Border.all(
              color: _isRunning
                  ? (isConnected || _isBroadcasting
                      ? Colors.cyanAccent.withOpacity(0.6)
                      : Colors.purpleAccent.withOpacity(0.4))
                  : Colors.redAccent.withOpacity(0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isRunning ? Colors.cyanAccent : Colors.redAccent).withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/brand/logo.png',
                      height: 14,
                      errorBuilder: (_, __, ___) => const Icon(Icons.bolt, size: 14, color: Colors.cyanAccent),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "LAGUN WEAR",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "TIEMPO LECTURA",
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  "${_readingTimeSec}s",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniMetric("ESTRÉS", "$_stressLevel%", _stressLevel > 70 ? Colors.redAccent : Colors.cyanAccent),
                    _buildMiniMetric("SUEÑO", "$_sleepQuality%", Colors.amberAccent),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isConnected ? Colors.greenAccent.withOpacity(0.4) : Colors.orangeAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? "LIVE" : "SYNC",
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 22,
                  child: ElevatedButton.icon(
                    onPressed: _toggleRunning,
                    icon: Icon(
                      _isRunning ? Icons.pause : Icons.play_arrow,
                      size: 10,
                    ),
                    label: Text(
                      _isRunning ? "PAUSAR" : "REANUDAR",
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.orangeAccent.withOpacity(0.8) : Colors.greenAccent.withOpacity(0.8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 20),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
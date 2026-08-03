import 'dart:async';
import 'dart:convert';
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
        scaffoldBackgroundColor: const Color(0xFF0D0D15),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.deepPurpleAccent,
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
  int _readingTimeSec = 0;
  int _articlesRead = 0;
  int _scrollActivity = 0;

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
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _readingTimeSec += 1;
        if (_readingTimeSec % 15 == 0) {
          _articlesRead += 1;
        }
        _scrollActivity = 60 + Random().nextInt(35);
      });

      _broadcastData();
    });
  }

  Future<void> _broadcastData() async {
    final Map<String, dynamic> telemetryData = {
      "time_sec": _readingTimeSec,
      "articles": _articlesRead,
      "activity": _scrollActivity,
    };

    final String jsonString = jsonEncode(telemetryData);
    final Uint8List payloadBytes = Uint8List.fromList(utf8.encode(jsonString));

    for (final client in _connectedClients) {
      try {
        client.writeln(jsonString);
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
    return Scaffold(
      body: Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _isBroadcasting || _connectedClients.isNotEmpty
                  ? Colors.cyanAccent
                  : Colors.grey,
              width: 2,
            ),
            gradient: RadialGradient(
              colors: [
                Colors.cyanAccent.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "LAGUN WEAR",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${_readingTimeSec}s",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniMetric("NOTICIAS", "$_articlesRead"),
                    _buildMiniMetric("ACTIVO", "$_scrollActivity%"),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sync,
                      size: 10,
                      color: _connectedClients.isNotEmpty
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _connectedClients.isNotEmpty
                          ? "MÓVIL CONECTADO"
                          : "ESPERANDO MÓVIL",
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: Colors.white54),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.cyanAccent,
          ),
        ),
      ],
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const LagunMobileApp());
}

class LagunMobileApp extends StatelessWidget {
  const LagunMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAGUN Noticias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.cyanAccent,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnected = false;
  int _readingTime = 0;
  int _articlesRead = 0;
  int _scrollActivity = 0;

  Socket? _bridgeSocket;
  Timer? _reconnectTimer;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndStartScan();
    _connectToWatchBridge();
  }

  Future<void> _requestPermissionsAndStartScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    _startBleScan();
  }

  void _startBleScan() async {
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid("0000180d-0000-1000-8000-00805f9b34fb")],
        timeout: const Duration(seconds: 15),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == 'LAGUN-Wear' ||
              r.advertisementData.advName == 'LAGUN-Wear') {
            r.advertisementData.manufacturerData.forEach((id, data) {
              try {
                final jsonString = utf8.decode(data);
                _parseAndUpdateMetrics(jsonString);
              } catch (_) {}
            });
          }
        }
      });
    } catch (_) {}
  }

  void _connectToWatchBridge() async {
    _reconnectTimer?.cancel();
    try {
      _bridgeSocket = await Socket.connect('10.0.2.2', 7777,
          timeout: const Duration(seconds: 3));

      if (mounted) {
        setState(() => _isConnected = true);
      }

      _bridgeSocket!.listen(
        (Uint8List data) {
          try {
            final String payload = utf8.decode(data);
            final List<String> lines = payload.split('\n');
            for (final line in lines) {
              final String cleanLine = line.trim();
              if (cleanLine.isNotEmpty) {
                _parseAndUpdateMetrics(cleanLine);
              }
            }
          } catch (_) {}
        },
        onDone: () => _handleDisconnection(),
        onError: (_) => _handleDisconnection(),
      );
    } catch (_) {
      _handleDisconnection();
    }
  }

  Future<void> _parseAndUpdateMetrics(String jsonString) async {
    try {
      final metrics = jsonDecode(jsonString);
      if (mounted) {
        setState(() {
          _isConnected = true;
          _readingTime = metrics['time_sec'] ?? _readingTime;
          _articlesRead = metrics['articles'] ?? _articlesRead;
          _scrollActivity = metrics['activity'] ?? _scrollActivity;
        });

        await _syncMetricsToSupabase(_readingTime, _articlesRead, _scrollActivity);
      }
    } catch (_) {}
  }

  Future<void> _syncMetricsToSupabase(int time, int articles, int activity) async {
    try {
      const String targetUserId = 'AQUÍ_PONE_EL_UUID_DE_UN_PERFIL_DE_SUPABASE';

      await Supabase.instance.client.from('user_telemetry_metrics').upsert({
        'user_id': targetUserId,
        'reading_time_sec': time,
        'articles_read': articles,
        'scroll_activity': activity,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Error al sincronizar con Supabase: $e');
    }
  }

  void _handleDisconnection() {
    if (mounted) {
      setState(() => _isConnected = false);
    }
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connectToWatchBridge();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _reconnectTimer?.cancel();
    _bridgeSocket?.close();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAGUN - Hub Móvil'),
        backgroundColor: const Color(0xFF18182B),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 20),
            const Text(
              "Telemetría Wear OS en Tiempo Real",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _buildMetricCard(
                    title: "Tiempo de Lectura",
                    value: "${_readingTime}s",
                    subtitle: "Tiempo activo consumiendo noticias",
                    icon: Icons.timer_outlined,
                    color: Colors.cyanAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    title: "Artículos Vistos",
                    value: "$_articlesRead",
                    subtitle: "Noticias completadas en la sesión",
                    icon: Icons.article_outlined,
                    color: Colors.amberAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    title: "Nivel de Scroll / Actividad",
                    value: "$_scrollActivity%",
                    subtitle: "Ritmo de interacción del usuario",
                    icon: Icons.touch_app_outlined,
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.watch_outlined : Icons.sync_problem,
            size: 32,
            color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected
                      ? "Conectado a LAGUN Wear"
                      : "Buscando señal de LAGUN Wear...",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isConnected
                      ? "Sincronizando telemetría y Supabase"
                      : "Verifica que el puente ADB esté activo",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18182B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
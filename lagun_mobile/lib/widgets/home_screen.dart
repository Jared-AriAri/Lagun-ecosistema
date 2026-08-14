import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tv_models.dart';
import 'telemetry_bar.dart';
import 'news_list.dart';
import 'profile_tab.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isConnected = false;
  bool _isOnline = true; // Control de estado de red / Supabase
  String _currentTime = '';
  Timer? _clockTimer;

  TelemetryMetrics _telemetry = TelemetryMetrics(
    readingTimeSec: 0,
    stressLevel: 0,
    sleepQuality: 0,
    needsRest: false,
  );

  List<TvItem> _items = [];
  List<TvItem> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isProfileLoading = false;
  String? _userAvatarUrl;
  String? _userEmail;
  String? _userRole;
  String? _profileSuccessMessage;
  String? _profileErrorMessage;

  Socket? _bridgeSocket;
  Timer? _reconnectTimer;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  RealtimeChannel? _supabaseChannel;

  @override
  void initState() {
    super.initState();
    _startClock();
    _loadData();
    _loadTelemetry();
    _loadUserProfile();
    _listenToSupabaseRealtime();
    _requestPermissionsAndStartScan();
    _connectToEmulatorBridge();
  }

  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    if (mounted) {
      setState(() => _currentTime = timeStr);
    }
  }

  Future<void> _loadData() async {
    try {
      final client = Supabase.instance.client;
      final newsArticles = await client.from('news_articles').select('id, slug, title, excerpt, cover_image_url').eq('status', 'published').limit(5);
      final reviews = await client.from('reviews').select('id, slug, title, rating, cover_image_url').eq('status', 'published').limit(5);

      final List<TvItem> fetchedItems = [];
      for (var news in newsArticles) {
        fetchedItems.add(TvItem(
          id: news['id'].toString(),
          slug: news['slug'] ?? '',
          type: 'news',
          title: news['title'] ?? '',
          subtitle: news['excerpt'] ?? '',
          imageUrl: news['cover_image_url'],
          tag: 'NOTICIA',
        ));
      }
      for (var review in reviews) {
        fetchedItems.add(TvItem(
          id: review['id'].toString(),
          slug: review['slug'] ?? '',
          type: 'reviews',
          title: review['title'] ?? '',
          subtitle: '',
          imageUrl: review['cover_image_url'],
          tag: 'RESEÑA',
          score: review['rating'] != null ? "${review['rating']}/10" : 'N/A',
        ));
      }

      if (mounted) {
        setState(() {
          _items = fetchedItems;
          _applyFilter(_searchController.text);
          _isOnline = true; // Conexión restaurada
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos (Modo offline): $e');
      if (mounted) {
        setState(() {
          _isOnline = false; // Sin conexión a red/servidor
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final client = Supabase.instance.client;
      var user = client.auth.currentUser;

      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        user = client.auth.currentUser;
      }

      if (user == null) return;

      if (mounted) {
        setState(() {
          _userEmail = user?.email;
        });
      }

      final userId = user?.id;
      if (userId == null) return;

      final response = await client
          .from('profiles')
          .select('full_name, bio, avatar_url, role')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _nameController.text = response['full_name']?.toString() ?? '';
          _bioController.text = response['bio']?.toString() ?? '';
          _userAvatarUrl = response['avatar_url']?.toString();
          _userRole = response['role']?.toString();
          _isOnline = true;
        });
      } else if (userId.isNotEmpty) {
        final defaultName = user?.email?.split('@').first ?? 'Usuario';
        await client.from('profiles').upsert({
          'id': userId,
          'full_name': defaultName,
          'bio': '',
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          setState(() {
            _nameController.text = defaultName;
            _bioController.text = '';
            _isOnline = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar perfil (Modo offline): $e');
      if (mounted) {
        setState(() {
          _isOnline = false;
          _profileErrorMessage = 'Sin conexión. Mostrando datos locales.';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isProfileLoading = true;
      _profileSuccessMessage = null;
      _profileErrorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _profileSuccessMessage = 'CONFIGURACIÓN GUARDADA EXITOSAMENTE';
          _isOnline = true;
        });
      }
    } catch (e) {
      debugPrint('Error al guardar perfil: $e');
      if (mounted) {
        setState(() {
          _isOnline = false;
          _profileErrorMessage = 'ERROR: Sin conexión a internet para guardar.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProfileLoading = false;
        });
      }
    }
  }

  Future<void> _loadTelemetry() async {
    try {
      final client = Supabase.instance.client;
      final data = await client.from('user_telemetry_metrics').select('reading_time_sec, articles_read, scroll_activity, stress_level, sleep_quality').order('updated_at', ascending: false).limit(1).maybeSingle();

      if (data != null && mounted) {
        _updateTelemetryState(data);
        setState(() => _isOnline = true);
      }
    } catch (e) {
      debugPrint('Error telemetría (Modo offline): $e');
      if (mounted) setState(() => _isOnline = false);
    }
  }

  void _updateTelemetryState(Map<String, dynamic> data) {
    final readingTime = data['reading_time_sec'] ?? 0;
    final stress = data['stress_level'] ?? data['scroll_activity'] ?? 0;
    final sleep = data['sleep_quality'] ?? data['articles_read'] ?? 0;
    final needsRest = stress > 70 || (sleep > 0 && sleep < 50);

    setState(() {
      _telemetry = TelemetryMetrics(
        readingTimeSec: readingTime,
        stressLevel: stress,
        sleepQuality: sleep,
        needsRest: needsRest,
      );
    });
  }

  void _listenToSupabaseRealtime() {
    final client = Supabase.instance.client;
    _supabaseChannel = client.channel('mobile-realtime-global');

    _supabaseChannel!
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'user_telemetry_metrics', callback: (payload) {
          if (payload.newRecord.isNotEmpty) _updateTelemetryState(payload.newRecord);
        })
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'news_articles', callback: (_) => _loadData())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'reviews', callback: (_) => _loadData())
        .subscribe();
  }

  void _applyFilter(String query) {
    final q = query.toLowerCase().trim();
    List<TvItem> baseList = _items;
    if (_currentIndex == 0) {
      baseList = _items.where((i) => i.tag == 'NOTICIA').toList();
    } else if (_currentIndex == 1) {
      baseList = _items.where((i) => i.tag == 'RESEÑA').toList();
    }

    if (q.isEmpty) {
      _filteredItems = List.from(baseList);
    } else {
      _filteredItems = baseList.where((item) => item.title.toLowerCase().contains(q) || item.tag.toLowerCase().contains(q)).toList();
    }
  }

  Future<void> _requestPermissionsAndStartScan() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    try {
      await FlutterBluePlus.startScan(withServices: [Guid("0000180d-0000-1000-8000-00805f9b34fb")], timeout: const Duration(seconds: 15));
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == 'LAGUN-Wear' || r.advertisementData.advName == 'LAGUN-Wear') {
            r.advertisementData.manufacturerData.forEach((id, data) {
              if (data.length >= 4) _processBinaryBytes(Uint8List.fromList(data));
            });
          }
        }
      });
    } catch (_) {}
  }

  void _connectToEmulatorBridge() async {
    _reconnectTimer?.cancel();
    try {
      _bridgeSocket = await Socket.connect('10.0.2.2', 7777, timeout: const Duration(seconds: 3));
      if (mounted) setState(() => _isConnected = true);
      _bridgeSocket!.listen(
        (Uint8List data) {
          if (data.length >= 4) _processBinaryBytes(data);
        },
        onDone: () => _handleDisconnection(),
        onError: (_) => _handleDisconnection(),
      );
    } catch (_) {
      _handleDisconnection();
    }
  }

  void _processBinaryBytes(Uint8List data) async {
    final time = (data[0] << 8) | data[1];
    final sleep = data[2];
    final stress = data[3];

    if (mounted) {
      setState(() => _isConnected = true);
      await _syncMetricsToSupabase(time, sleep, stress);
    }
  }

  Future<void> _syncMetricsToSupabase(int time, int sleep, int stress) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('user_telemetry_metrics').upsert({
        'user_id': userId,
        'reading_time_sec': time,
        'articles_read': sleep,
        'scroll_activity': stress,
        'stress_level': stress,
        'sleep_quality': sleep,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      
      if (mounted && !_isOnline) setState(() => _isOnline = true);
    } catch (e) {
      debugPrint("Error Sync (Offline): $e");
      if (mounted) setState(() => _isOnline = false);
    }
  }

  void _handleDisconnection() {
    if (mounted) setState(() => _isConnected = false);
    _reconnectTimer = Timer(const Duration(seconds: 4), () => _connectToEmulatorBridge());
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scanSubscription?.cancel();
    _reconnectTimer?.cancel();
    _bridgeSocket?.close();
    _supabaseChannel?.unsubscribe();
    FlutterBluePlus.stopScan();
    _searchController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0712),
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior de estado y marca
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/brand/logo.png',
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(Icons.bolt, color: Colors.cyanAccent),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LAGUN',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
                      ),
                      const Text(
                        ' · MÓVIL',
                        style: TextStyle(fontSize: 12, color: Colors.cyanAccent),
                      ),
                    ],
                  ),
                  Text(
                    _currentTime,
                    style: const TextStyle(fontSize: 12, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // Banner de advertencia offline (Aparece automáticamente si la red falla)
            if (!_isOnline)
              Container(
                width: double.infinity,
                color: Colors.amber.shade900.withOpacity(0.9),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'MODO OFFLINE · Sin conexión con Supabase',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),

            TelemetryBar(
              telemetry: _telemetry,
              isConnected: _isConnected,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentIndex == 2
                    ? ProfileTab(
                        key: const ValueKey(2),
                        nameController: _nameController,
                        bioController: _bioController,
                        isLoading: _isProfileLoading,
                        avatarUrl: _userAvatarUrl,
                        email: _userEmail,
                        role: _userRole,
                        successMessage: _profileSuccessMessage,
                        errorMessage: _profileErrorMessage,
                        onSave: _saveProfile,
                        onLogout: _logout,
                        onAvatarChanged: (newUrl) {
                          setState(() {
                            _userAvatarUrl = newUrl;
                          });
                        },
                      )
                    : NewsListSection(
                        key: ValueKey(_currentIndex),
                        items: _filteredItems,
                        searchController: _searchController,
                        onSearchChanged: (query) => setState(() => _applyFilter(query)),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF130F22),
          border: Border(top: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.article_rounded, 'NOTICIAS', Colors.cyanAccent),
            _buildNavItem(1, Icons.rate_review_rounded, 'RESEÑAS', Colors.purpleAccent),
            _buildProfileNavItem(2, 'PERFIL', Colors.greenAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color activeColor) {
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
            _applyFilter(_searchController.text);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: isSelected ? activeColor : Colors.transparent, width: 3),
            ),
            color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? activeColor : Colors.grey, size: isSelected ? 24 : 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavItem(int index, String label, Color activeColor) {
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          if (index == 2) {
            _loadUserProfile();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: isSelected ? activeColor : Colors.transparent, width: 3),
            ),
            color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isSelected ? 26 : 22,
                height: isSelected ? 26 : 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? activeColor : Colors.grey, width: 1.5),
                ),
                child: ClipOval(
                  child: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
                      ? Image.network(_userAvatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, size: 14, color: isSelected ? activeColor : Colors.grey))
                      : Icon(Icons.person, size: 14, color: isSelected ? activeColor : Colors.grey),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
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
import 'incident_report_screen.dart';
import '../auth/login_screen.dart';

/// Identidad de prueba desacoplada de la sesión global de Supabase.
class HomeProfileIdentity {
  final String id;
  final String? email;
  const HomeProfileIdentity({required this.id, this.email});
}

class HomeScreen extends StatefulWidget {
  final bool enableExternalServices;
  final String? bridgeHostOverride;
  final int? bridgePortOverride;
  final bool bridgeReconnectEnabled;
  final Future<Socket> Function(String host, int port)? bridgeConnectorOverride;
  final Future<void> Function(int time, int sleep, int stress)?
  metricsSyncOverride;
  final Future<Stream<Uint8List>> Function()? blePacketStreamOverride;
  final void Function(
    void Function(Map<String, dynamic>) onMetrics,
    void Function() onNews,
    void Function() onReviews,
  )?
  realtimeListenerOverride;
  final SupabaseClient? supabaseClientOverride;
  final Future<HomeProfileIdentity?> Function()? identityFetcher;
  final Future<List<Map<String, dynamic>>> Function()? newsFetcher;
  final Future<List<Map<String, dynamic>>> Function()? reviewsFetcher;
  final Future<Map<String, dynamic>?> Function(String userId)? profileFetcher;
  final Future<Map<String, dynamic>?> Function(String userId)? telemetryFetcher;
  final Future<Map<String, dynamic>?> Function(
    String userId,
    Map<String, dynamic> values,
  )?
  profileUpdater;
  final Future<void> Function(Map<String, dynamic> values)?
  metricsUpsertOverride;
  final Uint8List? initialBinaryPacket;
  final List<TvItem>? initialItems;
  final Map<String, dynamic>? initialTelemetry;

  const HomeScreen({
    super.key,
    this.enableExternalServices = true,
    this.bridgeHostOverride,
    this.bridgePortOverride,
    this.bridgeReconnectEnabled = true,
    this.bridgeConnectorOverride,
    this.metricsSyncOverride,
    this.blePacketStreamOverride,
    this.realtimeListenerOverride,
    this.supabaseClientOverride,
    this.identityFetcher,
    this.newsFetcher,
    this.reviewsFetcher,
    this.profileFetcher,
    this.telemetryFetcher,
    this.profileUpdater,
    this.metricsUpsertOverride,
    this.initialBinaryPacket,
    this.initialItems,
    this.initialTelemetry,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isConnected = false;
  bool _isOnline = true;
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
  StreamSubscription<Uint8List>? _testBleSubscription;
  RealtimeChannel? _supabaseChannel;
  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      _items = List<TvItem>.from(widget.initialItems!);
      _applyFilter(_searchController.text);
    }
    if (widget.initialTelemetry != null) {
      _updateTelemetryState(widget.initialTelemetry!);
    }
    _startClock();
    final useData =
        widget.enableExternalServices ||
        widget.newsFetcher != null ||
        widget.reviewsFetcher != null ||
        widget.supabaseClientOverride != null;
    final usePrivateData =
        widget.enableExternalServices ||
        widget.identityFetcher != null ||
        widget.profileFetcher != null ||
        widget.telemetryFetcher != null ||
        widget.supabaseClientOverride != null;
    if (useData) _loadData();
    if (usePrivateData) {
      _loadUserProfile();
      _loadTelemetry();
    }
    if (widget.realtimeListenerOverride != null ||
        widget.enableExternalServices) {
      _listenToSupabaseRealtime();
    }
    if (widget.blePacketStreamOverride != null ||
        widget.enableExternalServices) {
      _requestPermissionsAndStartScan();
    }
    if (widget.enableExternalServices ||
        widget.bridgeConnectorOverride != null ||
        widget.bridgeHostOverride != null ||
        widget.bridgePortOverride != null) {
      _connectToEmulatorBridge();
    }
    if (widget.initialBinaryPacket != null) {
      _processBinaryBytes(widget.initialBinaryPacket!);
    }
  }

  SupabaseClient get _client =>
      widget.supabaseClientOverride ?? Supabase.instance.client;

  Future<HomeProfileIdentity?> _getIdentity() async {
    if (widget.identityFetcher != null) return widget.identityFetcher!();
    // Sin un cliente inyectado, las pruebas aisladas nunca consultan el singleton.
    if (!widget.enableExternalServices && widget.supabaseClientOverride == null)
      return null;
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return HomeProfileIdentity(id: user.id, email: user.email);
  }

  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
  }

  void _updateClock() {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    if (mounted) {
      setState(() => _currentTime = timeStr);
    }
  }

  Future<void> _loadData() async {
    try {
      final newsArticles = widget.newsFetcher != null
          ? await widget.newsFetcher!()
          : await _client
                .from('news_articles')
                .select('id, slug, title, excerpt, cover_image_url')
                .eq('status', 'published')
                .limit(5);
      final reviews = widget.reviewsFetcher != null
          ? await widget.reviewsFetcher!()
          : await _client
                .from('reviews')
                .select('id, slug, title, rating, cover_image_url')
                .eq('status', 'published')
                .limit(5);
      final fetched = <TvItem>[];
      for (final news in newsArticles) {
        fetched.add(
          TvItem(
            id: news['id'].toString(),
            slug: news['slug']?.toString() ?? '',
            type: 'news',
            title: news['title']?.toString() ?? '',
            subtitle: news['excerpt']?.toString() ?? '',
            imageUrl: news['cover_image_url'],
            tag: 'NOTICIA',
          ),
        );
      }
      for (final review in reviews) {
        fetched.add(
          TvItem(
            id: review['id'].toString(),
            slug: review['slug']?.toString() ?? '',
            type: 'reviews',
            title: review['title']?.toString() ?? '',
            subtitle: '',
            imageUrl: review['cover_image_url'],
            tag: 'RESEÑA',
            score: review['rating'] == null ? 'N/A' : '${review['rating']}/10',
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _items = fetched;
        _applyFilter(_searchController.text);
        _isOnline = true;
      });
    } catch (e) {
      debugPrint('Error al cargar noticias o reseñas: $e');
      if (mounted && (e is SocketException || e is TimeoutException)) {
        setState(() => _isOnline = false);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      var identity = await _getIdentity();
      if (identity == null &&
          widget.enableExternalServices &&
          widget.identityFetcher == null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        identity = await _getIdentity();
      }
      if (identity == null || !mounted) return;
      setState(() => _userEmail = identity!.email);
      final response = widget.profileFetcher != null
          ? await widget.profileFetcher!(identity.id)
          : await _client
                .from('profiles')
                .select('full_name, bio, avatar_url, role')
                .eq('id', identity.id)
                .maybeSingle();
      if (!mounted) return;
      if (response == null) {
        setState(
          () => _profileErrorMessage =
              'No se encontró tu perfil. Comprueba que se haya creado al registrarte.',
        );
        return;
      }
      setState(() {
        _nameController.text = response['full_name']?.toString() ?? '';
        _bioController.text = response['bio']?.toString() ?? '';
        _userAvatarUrl = response['avatar_url']?.toString();
        _userRole = response['role']?.toString();
        _profileErrorMessage = null;
      });
    } on PostgrestException catch (e) {
      if (mounted)
        setState(
          () => _profileErrorMessage = 'Error al cargar perfil: ${e.message}',
        );
    } catch (e) {
      if (mounted)
        setState(
          () => _profileErrorMessage = 'No se pudo cargar el perfil: $e',
        );
    }
  }

  Future<void> _saveProfile() async {
    if (_isProfileLoading || !mounted) return;
    setState(() {
      _isProfileLoading = true;
      _profileSuccessMessage = null;
      _profileErrorMessage = null;
    });
    try {
      final identity = await _getIdentity();
      if (identity == null) throw StateError('Usuario no autenticado');
      final values = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      };
      final result = widget.profileUpdater != null
          ? await widget.profileUpdater!(identity.id, values)
          : await _client
                .from('profiles')
                .update(values)
                .eq('id', identity.id)
                .select('id')
                .maybeSingle();
      if (result == null) {
        throw StateError('No se encontró un perfil autorizado para actualizar');
      }
      if (!mounted) return;
      setState(() {
        _profileSuccessMessage = 'CONFIGURACIÓN GUARDADA EXITOSAMENTE';
        _profileErrorMessage = null;
      });
    } on PostgrestException catch (e) {
      if (mounted)
        setState(
          () => _profileErrorMessage = 'Error ${e.code ?? ''}: ${e.message}',
        );
    } catch (e) {
      if (mounted)
        setState(
          () => _profileErrorMessage = 'No se pudo guardar el perfil: $e',
        );
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _loadTelemetry() async {
    try {
      final identity = await _getIdentity();
      if (identity == null) return;
      final data = widget.telemetryFetcher != null
          ? await widget.telemetryFetcher!(identity.id)
          : await _client
                .from('user_telemetry_metrics')
                .select(
                  'reading_time_sec, articles_read, scroll_activity, stress_level, sleep_quality',
                )
                .eq('user_id', identity.id)
                .maybeSingle();
      if (data != null && mounted) {
        _updateTelemetryState(data);
        setState(() => _isOnline = true);
      }
    } catch (e) {
      debugPrint('Error al cargar telemetría: $e');
      if (mounted && (e is SocketException || e is TimeoutException)) {
        setState(() => _isOnline = false);
      }
    }
  }

  void _updateTelemetryState(Map<String, dynamic> data) {
    if (!mounted || data.isEmpty) return;
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
    final hook = widget.realtimeListenerOverride;
    if (hook != null) {
      hook(
        (values) {
          if (mounted && values.isNotEmpty) _updateTelemetryState(values);
        },
        () {
          if (mounted) _loadData();
        },
        () {
          if (mounted) _loadData();
        },
      );
      return;
    }
    if (!widget.enableExternalServices) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _supabaseChannel = _client.channel('mobile-realtime-$userId');
    _supabaseChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_telemetry_metrics',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (mounted && payload.newRecord.isNotEmpty) {
              _updateTelemetryState(payload.newRecord);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'news_articles',
          callback: (_) {
            if (mounted) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reviews',
          callback: (_) {
            if (mounted) _loadData();
          },
        )
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
      _filteredItems = baseList
          .where(
            (item) =>
                item.title.toLowerCase().contains(q) ||
                item.tag.toLowerCase().contains(q),
          )
          .toList();
    }
  }

  Future<void> _requestPermissionsAndStartScan() async {
    if (widget.blePacketStreamOverride != null) {
      try {
        final stream = await widget.blePacketStreamOverride!();
        if (!mounted) return;
        _testBleSubscription = stream.listen(
          (data) {
            if (data.length >= 4 && mounted) _processBinaryBytes(data);
          },
          onError: (Object error) {
            debugPrint('Error BLE simulado: $error');
          },
        );
      } catch (e) {
        debugPrint('Error al iniciar BLE simulado: $e');
      }
      return;
    }
    if (!widget.enableExternalServices) return;
    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      if (!mounted) return;
      await FlutterBluePlus.startScan(
        withServices: [Guid('0000180d-0000-1000-8000-00805f9b34fb')],
        timeout: const Duration(seconds: 15),
      );
      if (!mounted) return;
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == 'LAGUN-Wear' ||
              r.advertisementData.advName == 'LAGUN-Wear') {
            for (final data in r.advertisementData.manufacturerData.values) {
              if (data.length >= 4)
                _processBinaryBytes(Uint8List.fromList(data));
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error al iniciar BLE: $e');
    }
  }

  Future<void> _connectToEmulatorBridge() async {
    _reconnectTimer?.cancel();
    final host = widget.bridgeHostOverride ?? '10.0.2.2';
    final port = widget.bridgePortOverride ?? 7777;
    try {
      final socket = widget.bridgeConnectorOverride != null
          ? await widget.bridgeConnectorOverride!(host, port)
          : await Socket.connect(
              host,
              port,
              timeout: const Duration(seconds: 3),
            );
      if (!mounted) {
        socket.destroy();
        return;
      }
      _bridgeSocket = socket;
      setState(() => _isConnected = true);
      _bridgeSocket!.listen(
        (data) {
          if (mounted && data.length >= 4)
            _processBinaryBytes(Uint8List.fromList(data));
        },
        onDone: _handleDisconnection,
        onError: (Object error) {
          _handleDisconnection();
        },
      );
    } catch (e) {
      if (mounted) _handleDisconnection();
    }
  }

  Future<void> _processBinaryBytes(Uint8List data) async {
    if (!mounted || data.length < 4) return;
    final time = (data[0] << 8) | data[1];
    final sleep = data[2];
    final stress = data[3];
    setState(() => _isConnected = true);
    await _syncMetricsToSupabase(time, sleep, stress);
  }

  Future<void> _syncMetricsToSupabase(int time, int sleep, int stress) async {
    try {
      if (widget.metricsSyncOverride != null) {
        await widget.metricsSyncOverride!(time, sleep, stress);
        return;
      }
      final identity = await _getIdentity();
      if (identity == null) return;
      final values = <String, dynamic>{
        'user_id': identity.id,
        'reading_time_sec': time,
        'articles_read': sleep,
        'scroll_activity': stress,
        'stress_level': stress,
        'sleep_quality': sleep,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (widget.metricsUpsertOverride != null) {
        await widget.metricsUpsertOverride!(values);
      } else {
        await _client
            .from('user_telemetry_metrics')
            .upsert(values, onConflict: 'user_id');
      }
      if (mounted && !_isOnline) setState(() => _isOnline = true);
    } catch (e) {
      debugPrint('Error al sincronizar telemetría: $e');
      if (mounted && (e is SocketException || e is TimeoutException)) {
        setState(() => _isOnline = false);
      }
    }
  }

  void _handleDisconnection() {
    if (!mounted) return;
    setState(() => _isConnected = false);
    if (!widget.bridgeReconnectEnabled) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _connectToEmulatorBridge();
    });
  }

  Future<void> _logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scanSubscription?.cancel();
    _testBleSubscription?.cancel();
    _reconnectTimer?.cancel();
    _bridgeSocket?.destroy();
    _supabaseChannel?.unsubscribe();
    if (widget.enableExternalServices) {
      FlutterBluePlus.stopScan();
    }
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
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.bolt, color: Colors.cyanAccent),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LAGUN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        ' · MÓVIL',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _currentTime,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isOnline)
              Container(
                width: double.infinity,
                color: Colors.amber.shade900.withOpacity(0.9),
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'MODO OFFLINE · Sin conexión con Supabase',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            TelemetryBar(telemetry: _telemetry, isConnected: _isConnected),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentIndex == 3
                    ? ProfileTab(
                        key: const ValueKey(3),
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
                    : _currentIndex == 2
                    ? const IncidentReportScreen(key: ValueKey(2))
                    : NewsListSection(
                        key: ValueKey(_currentIndex),
                        items: _filteredItems,
                        searchController: _searchController,
                        onSearchChanged: (query) =>
                            setState(() => _applyFilter(query)),
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
          border: Border(
            top: BorderSide(
              color: Colors.cyanAccent.withOpacity(0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              0,
              Icons.article_rounded,
              'NOTICIAS',
              Colors.cyanAccent,
            ),
            _buildNavItem(
              1,
              Icons.rate_review_rounded,
              'RESEÑAS',
              Colors.purpleAccent,
            ),
            _buildNavItem(
              2,
              Icons.confirmation_number_rounded,
              'REPORTES',
              Colors.orangeAccent,
            ),
            _buildProfileNavItem(3, 'PERFIL', Colors.greenAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color activeColor,
  ) {
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
              top: BorderSide(
                color: isSelected ? activeColor : Colors.transparent,
                width: 3,
              ),
            ),
            color: isSelected
                ? activeColor.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : Colors.grey,
                size: isSelected ? 24 : 20,
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

  Widget _buildProfileNavItem(int index, String label, Color activeColor) {
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          if (index == 3 &&
              (widget.enableExternalServices ||
                  widget.profileFetcher != null ||
                  widget.supabaseClientOverride != null)) {
            _loadUserProfile();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isSelected ? activeColor : Colors.transparent,
                width: 3,
              ),
            ),
            color: isSelected
                ? activeColor.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isSelected ? 26 : 22,
                height: isSelected ? 26 : 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? activeColor : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
                      ? Image.network(
                          _userAvatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            size: 14,
                            color: isSelected ? activeColor : Colors.grey,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 14,
                          color: isSelected ? activeColor : Colors.grey,
                        ),
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

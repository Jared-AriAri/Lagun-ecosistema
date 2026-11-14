import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lagun_mobile/widgets/home_screen.dart';
import 'package:lagun_mobile/widgets/news_list.dart';
import 'package:lagun_mobile/widgets/profile_tab.dart';
import 'package:lagun_mobile/widgets/telemetry_bar.dart';

void main() {
  registerRealtimeBleWhiteBoxTests();
  registerPendingCoverageWhiteBoxTests();
  registerHomeSocketWhiteBoxTests();
  registerRestWhiteBoxTests();
  Future<void> showHome(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(enableExternalServices: false)),
    );
    await tester.pump();
  }

  group('White Box - Pantalla principal', () {
    testWidgets('WB-97: muestra la estructura principal de LAGUN', (
      tester,
    ) async {
      await showHome(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('LAGUN'), findsOneWidget);
      expect(find.text(' · MÓVIL'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(TelemetryBar), findsOneWidget);
    });
    testWidgets('WB-98: inicia en la sección de noticias', (tester) async {
      await showHome(tester);
      expect(find.byType(NewsListSection), findsOneWidget);
      expect(find.text('No se encontraron publicaciones'), findsOneWidget);
      expect(find.text('NOTICIAS'), findsOneWidget);
    });
    testWidgets('WB-99: permite cambiar a reseñas', (tester) async {
      await showHome(tester);
      await tester.tap(find.text('RESEÑAS'));
      await tester.pumpAndSettle();
      expect(find.byType(NewsListSection), findsOneWidget);
      expect(find.text('No se encontraron publicaciones'), findsOneWidget);
      expect(find.text('RESEÑAS'), findsOneWidget);
    });
    testWidgets('WB-100: permite regresar de reseñas a noticias', (
      tester,
    ) async {
      await showHome(tester);
      await tester.tap(find.text('RESEÑAS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NOTICIAS'));
      await tester.pumpAndSettle();
      expect(find.byType(NewsListSection), findsOneWidget);
      expect(find.text('No se encontraron publicaciones'), findsOneWidget);
    });
  });
}

void registerHomeSocketWhiteBoxTests() {
  group('White Box - Puente de smartwatch por socket', () {
    testWidgets('WB-141: conexión local, paquete y desconexión', (
      tester,
    ) async {
      final sockets = await tester.runAsync(() async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final incoming = server.first;
        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );
        final remote = await incoming.timeout(const Duration(seconds: 3));
        return (server: server, client: client, remote: remote);
      });
      expect(sockets, isNotNull);
      final server = sockets!.server;
      final client = sockets.client;
      final remote = sockets.remote;
      final received = <List<int>>[];
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              enableExternalServices: false,
              bridgeHostOverride: '127.0.0.1',
              bridgePortOverride: server.port,
              bridgeReconnectEnabled: false,
              bridgeConnectorOverride: (host, port) async {
                expect(host, '127.0.0.1');
                expect(port, server.port);
                return client;
              },
              metricsSyncOverride: (time, sleep, stress) async {
                received.add([time, sleep, stress]);
              },
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.widget<TelemetryBar>(find.byType(TelemetryBar)).isConnected,
          isTrue,
        );
        await tester.runAsync(() async {
          remote.add([1, 2, 80, 30]);
          await remote.flush();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        expect(received, [
          [258, 80, 30],
        ]);
        await tester.runAsync(() async {
          remote.destroy();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        expect(
          tester.widget<TelemetryBar>(find.byType(TelemetryBar)).isConnected,
          isFalse,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        client.destroy();
        remote.destroy();
        await tester.runAsync(() => server.close());
      }
    });
    testWidgets('WB-142: conexión rechazada sin reintentos infinitos', (
      tester,
    ) async {
      final temporary = await tester.runAsync(
        () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      );
      expect(temporary, isNotNull);
      final server = temporary!;
      final port = server.port;
      await tester.runAsync(() => server.close());
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            bridgeHostOverride: '127.0.0.1',
            bridgePortOverride: port,
            bridgeReconnectEnabled: false,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      expect(
        tester.widget<TelemetryBar>(find.byType(TelemetryBar)).isConnected,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

void registerRestWhiteBoxTests() {
  Future<void> mountHome(
    WidgetTester tester, {
    Future<List<Map<String, dynamic>>> Function()? newsFetcher,
    Future<List<Map<String, dynamic>>> Function()? reviewsFetcher,
    Future<HomeProfileIdentity?> Function()? identityFetcher,
    Future<Map<String, dynamic>?> Function(String userId)? profileFetcher,
    Future<Map<String, dynamic>?> Function(String userId)? telemetryFetcher,
    Future<Map<String, dynamic>?> Function(
      String userId,
      Map<String, dynamic> values,
    )?
    profileUpdater,
    Future<void> Function(Map<String, dynamic> values)? metricsUpsertOverride,
    Uint8List? packet,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          enableExternalServices: false,
          newsFetcher: newsFetcher,
          reviewsFetcher: reviewsFetcher,
          identityFetcher: identityFetcher,
          profileFetcher: profileFetcher,
          telemetryFetcher: telemetryFetcher,
          profileUpdater: profileUpdater,
          metricsUpsertOverride: metricsUpsertOverride,
          initialBinaryPacket: packet,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('White Box - Operaciones de datos simuladas', () {
    testWidgets('WB-150: carga noticias y reseñas sin red externa', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        var newsCalls = 0;
        var reviewsCalls = 0;
        await mountHome(
          tester,
          newsFetcher: () async {
            newsCalls++;
            return [
              {
                'id': 150,
                'slug': 'noticia-wb150',
                'title': 'Noticia controlada WB150',
                'excerpt': 'Contenido para la prueba',
                'cover_image_url': null,
              },
            ];
          },
          reviewsFetcher: () async {
            reviewsCalls++;
            return [
              {
                'id': 151,
                'slug': 'resena-wb150',
                'title': 'Reseña controlada WB150',
                'rating': 9,
                'cover_image_url': null,
              },
            ];
          },
        );
        expect(newsCalls, 1);
        expect(reviewsCalls, 1);
        final news = tester.widget<NewsListSection>(
          find.byType(NewsListSection),
        );
        expect(news.items, hasLength(1));
        expect(news.items.single.title, 'Noticia controlada WB150');
        expect(news.items.single.tag, 'NOTICIA');
        await tester.tap(find.text('RESEÑAS'));
        await tester.pumpAndSettle();
        final reviews = tester.widget<NewsListSection>(
          find.byType(NewsListSection),
        );
        expect(reviews.items, hasLength(1));
        expect(reviews.items.single.title, 'Reseña controlada WB150');
        expect(reviews.items.single.score, '9/10');
        expect(tester.takeException(), isNull);
      });
    });
    testWidgets('WB-151: carga perfil y telemetría por usuario', (
      tester,
    ) async {
      final queriedUsers = <String>[];
      await mountHome(
        tester,
        identityFetcher: () async => const HomeProfileIdentity(
          id: 'usuario-prueba',
          email: 'prueba@lagun.test',
        ),
        profileFetcher: (userId) async {
          queriedUsers.add('perfil:$userId');
          return {
            'full_name': 'Perfil simulado',
            'bio': 'Biografía simulada',
            'role': 'reader',
            'avatar_url': null,
          };
        },
        telemetryFetcher: (userId) async {
          queriedUsers.add('telemetria:$userId');
          return {
            'reading_time_sec': 300,
            'articles_read': 80,
            'scroll_activity': 20,
            'stress_level': 20,
            'sleep_quality': 80,
          };
        },
      );
      expect(queriedUsers, contains('perfil:usuario-prueba'));
      expect(queriedUsers, contains('telemetria:usuario-prueba'));
      final telemetry = tester.widget<TelemetryBar>(find.byType(TelemetryBar));
      expect(telemetry.telemetry.readingTimeSec, 300);
      expect(telemetry.telemetry.stressLevel, 20);
      expect(telemetry.telemetry.sleepQuality, 80);
      await tester.tap(find.text('PERFIL'));
      await tester.pumpAndSettle();
      final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(profile.nameController.text, 'Perfil simulado');
      expect(profile.bioController.text, 'Biografía simulada');
      expect(profile.role, 'reader');
      expect(profile.email, 'prueba@lagun.test');
    });
    testWidgets('WB-152: guarda perfil y sincroniza paquete sin red', (
      tester,
    ) async {
      Map<String, dynamic>? savedProfile;
      Map<String, dynamic>? savedMetrics;
      String? savedUserId;
      await mountHome(
        tester,
        identityFetcher: () async => const HomeProfileIdentity(
          id: 'usuario-prueba',
          email: 'prueba@lagun.test',
        ),
        profileFetcher: (_) async => {
          'full_name': 'Nombre anterior',
          'bio': 'Biografía anterior',
          'role': 'reader',
          'avatar_url': null,
        },
        profileUpdater: (userId, values) async {
          savedUserId = userId;
          savedProfile = Map<String, dynamic>.from(values);
          return {'id': userId};
        },
        metricsUpsertOverride: (values) async {
          savedMetrics = Map<String, dynamic>.from(values);
        },
        packet: Uint8List.fromList([0, 18, 52, 86]),
      );
      expect(savedMetrics, isNotNull);
      expect(savedMetrics!['user_id'], 'usuario-prueba');
      expect(savedMetrics!['reading_time_sec'], 18);
      expect(savedMetrics!['sleep_quality'], 52);
      expect(savedMetrics!['stress_level'], 86);
      await tester.tap(find.text('PERFIL'));
      await tester.pumpAndSettle();
      final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
      profile.nameController.text = '  Nuevo nombre  ';
      profile.bioController.text = '  Nueva biografía  ';
      profile.onSave();
      await tester.pumpAndSettle();
      expect(savedUserId, 'usuario-prueba');
      expect(savedProfile, {
        'full_name': 'Nuevo nombre',
        'bio': 'Nueva biografía',
      });
      expect(
        tester.widget<ProfileTab>(find.byType(ProfileTab)).successMessage,
        'CONFIGURACIÓN GUARDADA EXITOSAMENTE',
      );
    });
    testWidgets('WB-153: controla errores inesperados al cargar perfil', (
      tester,
    ) async {
      await mountHome(
        tester,
        identityFetcher: () async =>
            const HomeProfileIdentity(id: 'usuario-prueba'),
        profileFetcher: (_) async =>
            throw const FormatException('Formato inválido'),
      );
      await tester.tap(find.text('PERFIL'));
      await tester.pumpAndSettle();
      final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
      expect(profile.errorMessage, contains('Formato inválido'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('WB-154: sin sesión no lee datos privados', (tester) async {
      var publicCalls = 0;
      var profileCalls = 0;
      var telemetryCalls = 0;
      await mountHome(
        tester,
        newsFetcher: () async {
          publicCalls++;
          return <Map<String, dynamic>>[];
        },
        reviewsFetcher: () async => <Map<String, dynamic>>[],
        identityFetcher: () async => null,
        profileFetcher: (_) async {
          profileCalls++;
          return <String, dynamic>{};
        },
        telemetryFetcher: (_) async {
          telemetryCalls++;
          return <String, dynamic>{};
        },
      );
      expect(publicCalls, 1);
      expect(profileCalls, 0);
      expect(telemetryCalls, 0);
      await tester.tap(find.text('PERFIL'));
      await tester.pumpAndSettle();
      expect(profileCalls, 0);
      expect(telemetryCalls, 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets('WB-155: reconexión programada y cancelada al salir', (
      tester,
    ) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            bridgeHostOverride: '127.0.0.1',
            bridgePortOverride: 7777,
            bridgeReconnectEnabled: true,
            bridgeConnectorOverride: (host, port) async {
              attempts++;
              throw const SocketException('Conexión rechazada');
            },
          ),
        ),
      );
      await tester.pump();
      expect(attempts, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 8));
      expect(attempts, 2);
    });
  });
}

void registerRealtimeBleWhiteBoxTests() {
  group('White Box - Realtime y BLE simulados', () {
    testWidgets('WB-156: Realtime recibe métricas y actualiza la barra', (
      tester,
    ) async {
      late void Function(Map<String, dynamic>) notifyMetrics;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            realtimeListenerOverride: (onMetrics, onNews, onReviews) {
              notifyMetrics = onMetrics;
            },
          ),
        ),
      );
      notifyMetrics({
        'reading_time_sec': 600,
        'stress_level': 82,
        'sleep_quality': 31,
      });
      await tester.pump();
      final bar = tester.widget<TelemetryBar>(find.byType(TelemetryBar));
      expect(bar.telemetry.readingTimeSec, 600);
      expect(bar.telemetry.stressLevel, 82);
      expect(bar.telemetry.sleepQuality, 31);
      expect(bar.telemetry.needsRest, isTrue);
      notifyMetrics({});
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
    testWidgets('WB-157: Realtime refresca noticias y reseñas', (tester) async {
      await mockNetworkImagesFor(() async {
        late void Function() onNews;
        late void Function() onReviews;
        var newsCalls = 0;
        var reviewsCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              enableExternalServices: false,
              realtimeListenerOverride: (onMetrics, news, reviews) {
                onNews = news;
                onReviews = reviews;
              },
              newsFetcher: () async {
                newsCalls++;
                return <Map<String, dynamic>>[];
              },
              reviewsFetcher: () async {
                reviewsCalls++;
                return <Map<String, dynamic>>[];
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(newsCalls, 1);
        expect(reviewsCalls, 1);
        onNews();
        await tester.pumpAndSettle();
        expect(newsCalls, 2);
        expect(reviewsCalls, 2);
        onReviews();
        await tester.pumpAndSettle();
        expect(newsCalls, 3);
        expect(reviewsCalls, 3);
      });
    });
    testWidgets('WB-158: BLE recibe paquetes válidos e ignora incompletos', (
      tester,
    ) async {
      final controller = StreamController<Uint8List>.broadcast(sync: true);
      final received = <List<int>>[];
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            blePacketStreamOverride: () async => controller.stream,
            metricsSyncOverride: (time, sleep, stress) async {
              received.add([time, sleep, stress]);
            },
          ),
        ),
      );
      await tester.pump();
      expect(controller.hasListener, isTrue);
      controller.add(Uint8List.fromList([4, 9]));
      controller.add(Uint8List.fromList([1, 4, 60, 92]));
      await tester.pump();
      expect(received, [
        [260, 60, 92],
      ]);
      expect(
        tester.widget<TelemetryBar>(find.byType(TelemetryBar)).isConnected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.hasListener, isFalse);
    });
    testWidgets('WB-159: error de inicio de BLE no rompe la pantalla', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            blePacketStreamOverride: () async =>
                throw StateError('Escaneo fallido'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('WB-160: error del flujo BLE se controla y se libera', (
      tester,
    ) async {
      final controller = StreamController<Uint8List>.broadcast(sync: true);
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            blePacketStreamOverride: () async => controller.stream,
          ),
        ),
      );
      await tester.pump();
      controller.addError(StateError('Notificación BLE interrumpida'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.hasListener, isFalse);
    });
    testWidgets(
      'WB-161: notificación Realtime después del desmontaje se ignora',
      (tester) async {
        late void Function(Map<String, dynamic>) onMetrics;
        late void Function() onNews;
        late void Function() onReviews;
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              enableExternalServices: false,
              realtimeListenerOverride: (metrics, news, reviews) {
                onMetrics = metrics;
                onNews = news;
                onReviews = reviews;
              },
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        onMetrics({'reading_time_sec': 10});
        onNews();
        onReviews();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

void registerPendingCoverageWhiteBoxTests() {
  group('White Box - Cobertura de integraciones existentes', () {
    testWidgets(
      'WB-162: PostgREST consulta noticias y reseñas con transporte simulado',
      (tester) async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://lagun-pruebas.supabase.co',
          'clave-publica-de-pruebas',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              enableExternalServices: false,
              supabaseClientOverride: client,
              identityFetcher: () async => null,
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump(const Duration(milliseconds: 100));
        expect(requests.length, 2);
        expect(
          requests.where((r) => r.url.pathSegments.last == 'news_articles'),
          hasLength(1),
        );
        expect(
          requests.where((r) => r.url.pathSegments.last == 'reviews'),
          hasLength(1),
        );
        expect(
          requests.every((r) => r.url.host == 'lagun-pruebas.supabase.co'),
          isTrue,
        );
        expect(find.byType(NewsListSection), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'WB-163: PostgREST lee el perfil y la telemetría sin servicios externos',
      (tester) async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://lagun-pruebas.supabase.co',
          'clave-publica-de-pruebas',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request);
            final resource = request.url.pathSegments.last;
            Object data;
            if (resource == 'profiles') {
              data = {
                'full_name': 'Perfil verificado',
                'bio': 'Datos recibidos',
                'avatar_url': null,
                'role': 'reader',
              };
            } else if (resource == 'user_telemetry_metrics') {
              data = {
                'reading_time_sec': 700,
                'stress_level': 30,
                'sleep_quality': 90,
              };
            } else {
              data = <Object>[];
            }
            return http.Response(
              jsonEncode(data),
              200,
              request: request,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              enableExternalServices: false,
              supabaseClientOverride: client,
              identityFetcher: () async => const HomeProfileIdentity(
                id: 'wb163',
                email: 'perfil@lagun.test',
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(
          requests.any((r) => r.url.pathSegments.last == 'profiles'),
          isTrue,
        );
        expect(
          requests.any(
            (r) => r.url.pathSegments.last == 'user_telemetry_metrics',
          ),
          isTrue,
        );
        expect(
          tester
              .widget<TelemetryBar>(find.byType(TelemetryBar))
              .telemetry
              .readingTimeSec,
          700,
        );
        await tester.tap(find.text('PERFIL'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
        expect(profile.nameController.text, 'Perfil verificado');
        expect(profile.email, 'perfil@lagun.test');
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('WB-164: PostgREST actualiza el perfil y sincroniza métricas', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://lagun-pruebas.supabase.co',
        'clave-publica-de-pruebas',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final resource = request.url.pathSegments.last;
          final response = request.method == 'PATCH' && resource == 'profiles'
              ? jsonEncode({'id': 'wb164'})
              : request.method == 'POST' && resource == 'user_telemetry_metrics'
              ? '[]'
              : resource == 'profiles'
              ? jsonEncode({
                  'full_name': 'Anterior',
                  'bio': 'Anterior',
                  'avatar_url': null,
                  'role': 'reader',
                })
              : resource == 'user_telemetry_metrics'
              ? jsonEncode({
                  'reading_time_sec': 0,
                  'stress_level': 0,
                  'sleep_quality': 0,
                })
              : '[]';
          return http.Response(
            response,
            request.method == 'POST' ? 201 : 200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            supabaseClientOverride: client,
            identityFetcher: () async => const HomeProfileIdentity(id: 'wb164'),
            initialBinaryPacket: Uint8List.fromList([0, 12, 80, 25]),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (r) =>
              r.method == 'POST' &&
              r.url.pathSegments.last == 'user_telemetry_metrics',
        ),
        isTrue,
      );
      await tester.tap(find.text('PERFIL'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
      profile.nameController.text = 'Actualizado';
      profile.bioController.text = 'Prueba REST';
      profile.onSave();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final updates = requests
          .where(
            (r) => r.method == 'PATCH' && r.url.pathSegments.last == 'profiles',
          )
          .toList();
      expect(updates, hasLength(1));
      expect(jsonDecode(updates.single.body)['full_name'], 'Actualizado');
      expect(
        tester.widget<ProfileTab>(find.byType(ProfileTab)).successMessage,
        'CONFIGURACIÓN GUARDADA EXITOSAMENTE',
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'WB-165: la actualización del avatar cambia la imagen de navegación',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: HomeScreen(
                enableExternalServices: false,
                identityFetcher: () async =>
                    const HomeProfileIdentity(id: 'wb165'),
                profileFetcher: (_) async => {
                  'full_name': 'Perfil',
                  'bio': '',
                  'role': 'reader',
                  'avatar_url': null,
                },
              ),
            ),
          );
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          await tester.tap(find.text('PERFIL'));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          final profile = tester.widget<ProfileTab>(find.byType(ProfileTab));
          expect(profile.onAvatarChanged, isNotNull);
          profile.onAvatarChanged!(
            'https://lagun-pruebas.supabase.co/avatar.png',
          );
          await tester.pump();
          expect(find.byType(Image), findsWidgets);
          expect(tester.takeException(), isNull);
        });
      },
    );
    testWidgets('WB-166: conexión tardía se cierra al desmontar la pantalla', (
      tester,
    ) async {
      final pending = Completer<Socket>();
      final sockets = await tester.runAsync(() async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final incoming = server.first;
        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );
        final remote = await incoming;
        return (server: server, client: client, remote: remote);
      });
      expect(sockets, isNotNull);
      final server = sockets!.server;
      final client = sockets.client;
      final remote = sockets.remote;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              enableExternalServices: false,
              bridgeHostOverride: '127.0.0.1',
              bridgePortOverride: server.port,
              bridgeReconnectEnabled: false,
              bridgeConnectorOverride: (_, _) => pending.future,
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete(client);
        await tester.pump();
        expect(find.byType(HomeScreen), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        if (!pending.isCompleted) pending.complete(client);
        client.destroy();
        remote.destroy();
        await tester.runAsync(() => server.close());
      }
    });
    testWidgets('WB-167: flujo BLE tardío no se suscribe tras el desmontaje', (
      tester,
    ) async {
      final pending = Completer<Stream<Uint8List>>();
      final stream = StreamController<Uint8List>.broadcast(sync: true);
      addTearDown(stream.close);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            enableExternalServices: false,
            blePacketStreamOverride: () => pending.future,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(stream.stream);
      await tester.pump();
      expect(stream.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

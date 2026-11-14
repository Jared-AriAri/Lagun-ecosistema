import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/widgets/home_screen.dart';
import 'package:lagun_mobile/widgets/telemetry_bar.dart';

void main() {
  Future<HomeProfileIdentity?> validIdentity() async {
    return const HomeProfileIdentity(
      id: 'usuario-telemetria',
      email: 'telemetria@lagun.test',
    );
  }

  Future<void> showHome(
    WidgetTester tester, {
    Future<HomeProfileIdentity?> Function()? identityFetcher,
    Future<Map<String, dynamic>?> Function(String userId)? telemetryFetcher,
    Future<List<Map<String, dynamic>>> Function()? newsFetcher,
    Future<List<Map<String, dynamic>>> Function()? reviewsFetcher,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          enableExternalServices: false,
          identityFetcher: identityFetcher,
          telemetryFetcher: telemetryFetcher,
          newsFetcher: newsFetcher,
          reviewsFetcher: reviewsFetcher,
        ),
      ),
    );
    await tester.pump();
  }

  TelemetryBar barOf(WidgetTester tester) {
    return tester.widget<TelemetryBar>(find.byType(TelemetryBar));
  }

  group('White Box - Carga de telemetria', () {
    testWidgets('WB-135: carga metricas para el usuario autenticado', (
      tester,
    ) async {
      String? consultedUser;
      var fetchCalls = 0;

      await showHome(
        tester,
        identityFetcher: validIdentity,
        telemetryFetcher: (userId) async {
          fetchCalls++;
          consultedUser = userId;
          return {
            'reading_time_sec': 360,
            'stress_level': 75,
            'sleep_quality': 80,
          };
        },
      );
      await tester.pumpAndSettle();

      final bar = barOf(tester);
      expect(fetchCalls, 1);
      expect(consultedUser, 'usuario-telemetria');
      expect(bar.telemetry.readingTimeSec, 360);
      expect(bar.telemetry.stressLevel, 75);
      expect(bar.telemetry.sleepQuality, 80);
      expect(bar.telemetry.needsRest, isTrue);
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('WB-136: respuesta vacia conserva los valores iniciales', (
      tester,
    ) async {
      var fetchCalls = 0;

      await showHome(
        tester,
        identityFetcher: validIdentity,
        telemetryFetcher: (userId) async {
          fetchCalls++;
          return null;
        },
      );
      await tester.pumpAndSettle();

      final bar = barOf(tester);
      expect(fetchCalls, 1);
      expect(bar.telemetry.readingTimeSec, 0);
      expect(bar.telemetry.stressLevel, 0);
      expect(bar.telemetry.sleepQuality, 0);
      expect(bar.telemetry.needsRest, isFalse);
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsNothing,
      );
    });

    testWidgets('WB-137: sin sesion no se consultan las metricas', (
      tester,
    ) async {
      var fetchCalls = 0;

      await showHome(
        tester,
        identityFetcher: () async => null,
        telemetryFetcher: (userId) async {
          fetchCalls++;
          return {'reading_time_sec': 999};
        },
      );
      await tester.pumpAndSettle();

      expect(fetchCalls, 0);
      expect(barOf(tester).telemetry.readingTimeSec, 0);
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('WB-138: error SocketException activa modo offline', (
      tester,
    ) async {
      await showHome(
        tester,
        identityFetcher: validIdentity,
        telemetryFetcher: (userId) async {
          throw const SocketException('Red desconectada al leer telemetria');
        },
      );
      await tester.pumpAndSettle();

      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsOneWidget,
      );
      expect(barOf(tester).telemetry.readingTimeSec, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WB-139: TimeoutException activa modo offline', (tester) async {
      await showHome(
        tester,
        identityFetcher: validIdentity,
        telemetryFetcher: (userId) async {
          throw TimeoutException('Tiempo de espera agotado');
        },
      );
      await tester.pumpAndSettle();

      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsOneWidget,
      );
      expect(barOf(tester).telemetry.stressLevel, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WB-140: lectura exitosa recupera estado online', (
      tester,
    ) async {
      final pendingTelemetry = Completer<Map<String, dynamic>?>();
      var fetchCalls = 0;

      await showHome(
        tester,
        identityFetcher: validIdentity,
        newsFetcher: () async {
          throw const SocketException('Noticias sin conexion');
        },
        reviewsFetcher: () async => [],
        telemetryFetcher: (userId) {
          fetchCalls++;
          return pendingTelemetry.future;
        },
      );
      await tester.pumpAndSettle();

      expect(fetchCalls, 1);
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsOneWidget,
      );

      pendingTelemetry.complete({
        'reading_time_sec': 420,
        'stress_level': 25,
        'sleep_quality': 90,
      });
      await tester.pumpAndSettle();

      final bar = barOf(tester);
      expect(bar.telemetry.readingTimeSec, 420);
      expect(bar.telemetry.stressLevel, 25);
      expect(bar.telemetry.sleepQuality, 90);
      expect(bar.telemetry.needsRest, isFalse);
      expect(
        find.text('MODO OFFLINE · Sin conexión con Supabase'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

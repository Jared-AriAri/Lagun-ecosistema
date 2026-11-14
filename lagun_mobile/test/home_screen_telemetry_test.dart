import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/widgets/home_screen.dart';
import 'package:lagun_mobile/widgets/telemetry_bar.dart';

void main() {
  Future<void> showHome(
    WidgetTester tester, {
    Map<String, dynamic>? telemetry,
    Uint8List? packet,
    Future<void> Function(int time, int sleep, int stress)? onSync,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          enableExternalServices: false,
          initialTelemetry: telemetry,
          initialBinaryPacket: packet,
          metricsSyncOverride: onSync,
        ),
      ),
    );

    await tester.pump();
  }

  TelemetryBar getTelemetryBar(WidgetTester tester) {
    return tester.widget<TelemetryBar>(find.byType(TelemetryBar));
  }

  group('White Box - Telemetría y paquetes binarios', () {
    testWidgets('WB-111: valores ausentes usan cero', (tester) async {
      await showHome(tester, telemetry: <String, dynamic>{});

      final bar = getTelemetryBar(tester);

      expect(bar.telemetry.readingTimeSec, 0);
      expect(bar.telemetry.stressLevel, 0);
      expect(bar.telemetry.sleepQuality, 0);
      expect(bar.telemetry.needsRest, isFalse);
    });

    testWidgets('WB-112: sueño cero no activa descanso', (tester) async {
      await showHome(
        tester,
        telemetry: {
          'reading_time_sec': 60,
          'stress_level': 70,
          'sleep_quality': 0,
        },
      );

      final bar = getTelemetryBar(tester);

      expect(bar.telemetry.readingTimeSec, 60);
      expect(bar.telemetry.stressLevel, 70);
      expect(bar.telemetry.sleepQuality, 0);
      expect(bar.telemetry.needsRest, isFalse);
    });

    testWidgets('WB-113: sueño 50 no activa descanso', (tester) async {
      await showHome(
        tester,
        telemetry: {
          'reading_time_sec': 180,
          'stress_level': 70,
          'sleep_quality': 50,
        },
      );

      final bar = getTelemetryBar(tester);

      expect(bar.telemetry.readingTimeSec, 180);
      expect(bar.telemetry.stressLevel, 70);
      expect(bar.telemetry.sleepQuality, 50);
      expect(bar.telemetry.needsRest, isFalse);
    });

    testWidgets(
      'WB-114: utiliza métricas alternativas cuando faltan las principales',
      (tester) async {
        await showHome(
          tester,
          telemetry: {
            'reading_time_sec': 240,
            'scroll_activity': 71,
            'articles_read': 80,
          },
        );

        final bar = getTelemetryBar(tester);

        expect(bar.telemetry.readingTimeSec, 240);
        expect(bar.telemetry.stressLevel, 71);
        expect(bar.telemetry.sleepQuality, 80);
        expect(bar.telemetry.needsRest, isTrue);
      },
    );

    testWidgets('WB-115: interpreta correctamente un tiempo de 16 bits', (
      tester,
    ) async {
      int? receivedTime;
      int? receivedSleep;
      int? receivedStress;
      var syncCount = 0;

      await showHome(
        tester,
        packet: Uint8List.fromList([1, 2, 80, 30]),
        onSync: (time, sleep, stress) async {
          syncCount++;
          receivedTime = time;
          receivedSleep = sleep;
          receivedStress = stress;
        },
      );

      expect(receivedTime, 258);
      expect(receivedSleep, 80);
      expect(receivedStress, 30);
      expect(syncCount, 1);

      final bar = getTelemetryBar(tester);
      expect(bar.isConnected, isTrue);
    });

    testWidgets('WB-116: acepta un paquete con todos los valores en cero', (
      tester,
    ) async {
      final receivedValues = <int>[];

      await showHome(
        tester,
        packet: Uint8List.fromList([0, 0, 0, 0]),
        onSync: (time, sleep, stress) async {
          receivedValues.addAll([time, sleep, stress]);
        },
      );

      expect(receivedValues, [0, 0, 0]);

      final bar = getTelemetryBar(tester);
      expect(bar.isConnected, isTrue);
    });

    testWidgets('WB-117: interpreta los valores máximos de cada campo', (
      tester,
    ) async {
      int? receivedTime;
      int? receivedSleep;
      int? receivedStress;

      await showHome(
        tester,
        packet: Uint8List.fromList([255, 255, 255, 255]),
        onSync: (time, sleep, stress) async {
          receivedTime = time;
          receivedSleep = sleep;
          receivedStress = stress;
        },
      );

      expect(receivedTime, 65535);
      expect(receivedSleep, 255);
      expect(receivedStress, 255);

      final bar = getTelemetryBar(tester);
      expect(bar.isConnected, isTrue);
    });

    testWidgets('WB-118: rechaza un paquete incompleto sin sincronizar', (
      tester,
    ) async {
      var syncCount = 0;

      await showHome(
        tester,
        packet: Uint8List.fromList([1, 2, 3]),
        onSync: (time, sleep, stress) async {
          syncCount++;
        },
      );

      expect(syncCount, 0);

      final bar = getTelemetryBar(tester);
      expect(bar.isConnected, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

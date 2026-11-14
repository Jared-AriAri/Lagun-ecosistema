import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/models/tv_models.dart';
import 'package:lagun_mobile/widgets/telemetry_bar.dart';

void main() {
  Future<void> render(
    WidgetTester tester, {
    required bool isConnected,
    required bool needsRest,
    int stress = 35,
    int sleep = 85,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TelemetryBar(
            telemetry: TelemetryMetrics(
              readingTimeSec: 120,
              stressLevel: stress,
              sleepQuality: sleep,
              needsRest: needsRest,
            ),
            isConnected: isConnected,
          ),
        ),
      ),
    );
  }

  group('WB-46 a WB-51: barra de telemetría', () {
    testWidgets('WB-46: presenta tiempo de lectura, estrés y sueño', (tester) async {
      await render(tester, isConnected: false, needsRest: false);
      expect(find.text('TIEMPO LECTURA'), findsOneWidget);
      expect(find.text('120s'), findsOneWidget);
      expect(find.text('ESTRÉS'), findsOneWidget);
      expect(find.text('35%'), findsOneWidget);
      expect(find.text('SUEÑO'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('WB-47: muestra SYNC sin conexión al reloj', (tester) async {
      await render(tester, isConnected: false, needsRest: false);
      expect(find.text('SYNC'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('WB-48: muestra LIVE con conexión al reloj', (tester) async {
      await render(tester, isConnected: true, needsRest: false);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('SYNC'), findsNothing);
    });

    testWidgets('WB-49: no muestra alerta si needsRest es falso', (tester) async {
      await render(tester, isConnected: true, needsRest: false);
      expect(find.textContaining('Alerta de Salud'), findsNothing);
    });

    testWidgets('WB-50: muestra alerta cuando needsRest es verdadero', (tester) async {
      await render(tester, isConnected: true, needsRest: true, stress: 85, sleep: 25);
      expect(find.textContaining('Alerta de Salud'), findsOneWidget);
    });

    testWidgets('WB-51: estrés en límite 70 y sueño en límite 50', (tester) async {
      await render(tester, isConnected: false, needsRest: false, stress: 70, sleep: 50);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('Alerta de Salud'), findsNothing);
    });
  });
}

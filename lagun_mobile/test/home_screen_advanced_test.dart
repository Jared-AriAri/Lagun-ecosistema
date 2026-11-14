
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/models/tv_models.dart';
import 'package:lagun_mobile/widgets/home_screen.dart';
import 'package:lagun_mobile/widgets/news_list.dart';
import 'package:lagun_mobile/widgets/profile_tab.dart';
import 'package:lagun_mobile/widgets/telemetry_bar.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  final sampleItems = [
    TvItem(
      id: 'news-101',
      slug: 'inteligencia-artificial',
      type: 'news',
      title: 'Inteligencia Artificial',
      subtitle: 'Avances tecnológicos',
      tag: 'NOTICIA',
    ),
    TvItem(
      id: 'news-102',
      slug: 'exploracion-espacial',
      type: 'news',
      title: 'Exploración Espacial',
      subtitle: 'Nueva misión espacial',
      tag: 'NOTICIA',
    ),
    TvItem(
      id: 'review-103',
      slug: 'resena-videojuego',
      type: 'reviews',
      title: 'Reseña de Videojuego',
      subtitle: 'Análisis completo',
      tag: 'RESEÑA',
      score: '9/10',
    ),
  ];

  Future<void> showHome(
    WidgetTester tester, {
    List<TvItem>? items,
    Map<String, dynamic>? telemetry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          enableExternalServices: false,
          initialItems: items,
          initialTelemetry: telemetry,
        ),
      ),
    );

    await tester.pump();
  }

  Future<void> tapSection(
    WidgetTester tester,
    String section,
  ) async {
    await tester.tap(find.text(section));
    await tester.pumpAndSettle();
  }

  group('White Box - HomeScreen avanzado', () {
    testWidgets(
      'WB-101: navega a la pestaña de perfil',
      (tester) async {
        await showHome(tester);

        await tapSection(tester, 'PERFIL');

        expect(find.byType(ProfileTab), findsOneWidget);
        expect(find.text('CARGANDO CORREO...'), findsOneWidget);
        expect(find.text('NOMBRE COMPLETO'), findsOneWidget);
        expect(find.text('BIOGRAFÍA'), findsOneWidget);
      },
    );

    testWidgets(
      'WB-102: regresa de perfil a noticias',
      (tester) async {
        await showHome(tester);

        await tapSection(tester, 'PERFIL');

        expect(find.byType(ProfileTab), findsOneWidget);

        await tapSection(tester, 'NOTICIAS');

        expect(find.byType(NewsListSection), findsOneWidget);
        expect(find.byType(ProfileTab), findsNothing);
      },
    );

    testWidgets(
      'WB-103: búsqueda vacía conserva las noticias',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await showHome(tester, items: sampleItems);

          final searchField = find.byType(TextField);

          await tester.enterText(searchField, '');
          await tester.pump();

          expect(
            find.text('Inteligencia Artificial'),
            findsOneWidget,
          );

          expect(
            find.text('Exploración Espacial'),
            findsOneWidget,
          );

          expect(
            find.text('Reseña de Videojuego'),
            findsNothing,
          );
        });
      },
    );

    testWidgets(
      'WB-104: búsqueda sin coincidencias muestra lista vacía',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await showHome(tester, items: sampleItems);

          await tester.enterText(
            find.byType(TextField),
            'contenido inexistente',
          );

          await tester.pump();

          expect(
            find.text('No se encontraron publicaciones'),
            findsOneWidget,
          );

          expect(
            find.text('Inteligencia Artificial'),
            findsNothing,
          );

          expect(
            find.text('Exploración Espacial'),
            findsNothing,
          );
        });
      },
    );

    testWidgets(
      'WB-105: noticias excluye publicaciones de reseñas',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await showHome(tester, items: sampleItems);

          expect(
            find.text('Inteligencia Artificial'),
            findsOneWidget,
          );

          expect(
            find.text('Exploración Espacial'),
            findsOneWidget,
          );

          expect(
            find.text('Reseña de Videojuego'),
            findsNothing,
          );
        });
      },
    );

    testWidgets(
      'WB-106: reseñas excluye publicaciones de noticias',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await showHome(tester, items: sampleItems);

          await tapSection(tester, 'RESEÑAS');

          expect(
            find.text('Reseña de Videojuego'),
            findsOneWidget,
          );

          expect(
            find.text('9/10'),
            findsOneWidget,
          );

          expect(
            find.text('Inteligencia Artificial'),
            findsNothing,
          );

          expect(
            find.text('Exploración Espacial'),
            findsNothing,
          );
        });
      },
    );

    testWidgets(
      'WB-107: búsqueda ignora mayúsculas y espacios',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await showHome(tester, items: sampleItems);

          await tester.enterText(
            find.byType(TextField),
            '  iNtElIgEnCiA  ',
          );

          await tester.pump();

          expect(
            find.text('Inteligencia Artificial'),
            findsOneWidget,
          );

          expect(
            find.text('Exploración Espacial'),
            findsNothing,
          );

          expect(
            find.text('Reseña de Videojuego'),
            findsNothing,
          );
        });
      },
    );

    testWidgets(
      'WB-108: estrés 70 no activa alerta de descanso',
      (tester) async {
        await showHome(
          tester,
          telemetry: {
            'reading_time_sec': 120,
            'stress_level': 70,
            'sleep_quality': 80,
          },
        );

        final telemetryBar = tester.widget<TelemetryBar>(
          find.byType(TelemetryBar),
        );

        expect(telemetryBar.telemetry.readingTimeSec, 120);
        expect(telemetryBar.telemetry.stressLevel, 70);
        expect(telemetryBar.telemetry.sleepQuality, 80);
        expect(telemetryBar.telemetry.needsRest, isFalse);
      },
    );

    testWidgets(
      'WB-109: estrés 71 activa alerta de descanso',
      (tester) async {
        await showHome(
          tester,
          telemetry: {
            'reading_time_sec': 120,
            'stress_level': 71,
            'sleep_quality': 80,
          },
        );

        final telemetryBar = tester.widget<TelemetryBar>(
          find.byType(TelemetryBar),
        );

        expect(telemetryBar.telemetry.stressLevel, 71);
        expect(telemetryBar.telemetry.needsRest, isTrue);
      },
    );

    testWidgets(
      'WB-110: sueño 49 activa descanso con estrés normal',
      (tester) async {
        await showHome(
          tester,
          telemetry: {
            'reading_time_sec': 120,
            'stress_level': 30,
            'sleep_quality': 49,
          },
        );

        final telemetryBar = tester.widget<TelemetryBar>(
          find.byType(TelemetryBar),
        );

        expect(telemetryBar.telemetry.stressLevel, 30);
        expect(telemetryBar.telemetry.sleepQuality, 49);
        expect(telemetryBar.telemetry.needsRest, isTrue);
      },
    );
  });
}

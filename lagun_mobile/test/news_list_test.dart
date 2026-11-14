import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/models/tv_models.dart';
import 'package:lagun_mobile/widgets/article_detail.dart';
import 'package:lagun_mobile/widgets/news_list.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  group('White Box - Lista de noticias', () {
    testWidgets('WB-89: muestra mensaje cuando no hay publicaciones', (
      tester,
    ) async {
      final searchController = TextEditingController();
      addTearDown(searchController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NewsListSection(
                  items: const [],
                  searchController: searchController,
                  onSearchChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No se encontraron publicaciones'), findsOneWidget);
    });

    testWidgets('WB-90: muestra el campo de búsqueda', (tester) async {
      final searchController = TextEditingController();
      addTearDown(searchController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NewsListSection(
                  items: const [],
                  searchController: searchController,
                  onSearchChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Buscar reseña o noticia...'), findsOneWidget);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('WB-91: comunica los cambios de búsqueda', (tester) async {
      final searchController = TextEditingController();
      addTearDown(searchController.dispose);

      String? receivedQuery;
      var callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NewsListSection(
                  items: const [],
                  searchController: searchController,
                  onSearchChanged: (query) {
                    callbackCount++;
                    receivedQuery = query;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Tecnología');

      await tester.pump();

      expect(searchController.text, 'Tecnología');
      expect(receivedQuery, 'Tecnología');
      expect(callbackCount, greaterThanOrEqualTo(1));
    });

    testWidgets('WB-92: muestra correctamente una noticia', (tester) async {
      await mockNetworkImagesFor(() async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        final items = [
          TvItem(
            id: 'noticia-92',
            slug: 'noticia-tecnologia',
            type: 'news',
            title: 'Avances tecnológicos',
            subtitle: 'Nueva tecnología presentada',
            tag: 'NOTICIA',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  NewsListSection(
                    items: items,
                    searchController: controller,
                    onSearchChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Avances tecnológicos'), findsOneWidget);

        expect(find.text('Nueva tecnología presentada'), findsOneWidget);

        expect(find.text('NOTICIA'), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
      });
    });

    testWidgets('WB-93: muestra puntuación cuando es una reseña', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        final items = [
          TvItem(
            id: 'resena-93',
            slug: 'resena-videojuego',
            type: 'reviews',
            title: 'Reseña de videojuego',
            subtitle: 'Análisis del videojuego',
            tag: 'RESEÑA',
            score: '9/10',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  NewsListSection(
                    items: items,
                    searchController: controller,
                    onSearchChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Reseña de videojuego'), findsOneWidget);

        expect(find.text('RESEÑA'), findsOneWidget);
        expect(find.text('9/10'), findsOneWidget);
      });
    });

    testWidgets('WB-94: oculta puntuación cuando no existe', (tester) async {
      await mockNetworkImagesFor(() async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        final items = [
          TvItem(
            id: 'noticia-94',
            slug: 'noticia-sin-puntuacion',
            type: 'news',
            title: 'Noticia sin calificación',
            subtitle: 'Contenido de prueba',
            tag: 'NOTICIA',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  NewsListSection(
                    items: items,
                    searchController: controller,
                    onSearchChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Noticia sin calificación'), findsOneWidget);

        expect(find.text('9/10'), findsNothing);
      });
    });

    testWidgets('WB-95: abre el detalle al seleccionar noticia', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        final items = [
          TvItem(
            id: 'noticia-95',
            slug: 'noticia-detalle',
            type: 'news',
            title: 'Noticia interactiva',
            subtitle: 'Detalles de la publicación',
            tag: 'NOTICIA',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  NewsListSection(
                    items: items,
                    searchController: controller,
                    onSearchChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump();

        await tester.tap(find.text('Noticia interactiva'));

        await tester.pumpAndSettle();

        expect(find.byType(ArticleDetailModal), findsOneWidget);

        expect(find.text('Detalles de la publicación'), findsWidgets);

        expect(find.text('Cerrar Lectura'), findsOneWidget);
      });
    });

    testWidgets('WB-96: muestra varias publicaciones correctamente', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        final items = [
          TvItem(
            id: 'noticia-96-a',
            slug: 'primera-noticia',
            type: 'news',
            title: 'Primera noticia',
            subtitle: 'Descripción primera',
            tag: 'NOTICIA',
          ),
          TvItem(
            id: 'resena-96-b',
            slug: 'segunda-resena',
            type: 'reviews',
            title: 'Segunda reseña',
            subtitle: 'Descripción segunda',
            tag: 'RESEÑA',
            score: '8/10',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  NewsListSection(
                    items: items,
                    searchController: controller,
                    onSearchChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Primera noticia'), findsOneWidget);

        expect(find.text('Segunda reseña'), findsOneWidget);

        expect(find.text('8/10'), findsOneWidget);
      });
    });
  });
}

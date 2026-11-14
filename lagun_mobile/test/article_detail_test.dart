import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/models/tv_models.dart';
import 'package:lagun_mobile/widgets/article_detail.dart';

void main() {
  TvItem createArticle({String? imageUrl, String? score}) {
    return TvItem(
      id: 'article-001',
      slug: 'noticia-prueba',
      type: 'news',
      title: 'Noticia de prueba LAGUN',
      subtitle: 'Contenido descriptivo de la noticia.',
      imageUrl: imageUrl,
      tag: 'TECNOLOGÍA',
      score: score,
    );
  }

  Future<void> openArticle(WidgetTester tester, TvItem item) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ArticleDetailModal.show(context, item);
                },
                child: const Text('ABRIR ARTÍCULO'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('ABRIR ARTÍCULO'));
    await tester.pumpAndSettle();
  }

  group('White Box - Detalle de noticias', () {
    testWidgets('WB-73: abre correctamente el modal de noticia', (
      tester,
    ) async {
      await openArticle(tester, createArticle());

      expect(find.byType(ArticleDetailModal), findsOneWidget);

      expect(find.text('Noticia de prueba LAGUN'), findsOneWidget);

      expect(find.text('Contenido descriptivo de la noticia.'), findsOneWidget);
    });

    testWidgets('WB-74: muestra correctamente la categoría', (tester) async {
      await openArticle(tester, createArticle());

      expect(find.text('TECNOLOGÍA'), findsOneWidget);
    });

    testWidgets('WB-75: oculta la puntuación cuando es nula', (tester) async {
      await openArticle(tester, createArticle(score: null));

      expect(find.text('9.5'), findsNothing);

      expect(find.text('TECNOLOGÍA'), findsOneWidget);
    });

    testWidgets('WB-76: muestra la puntuación cuando existe', (tester) async {
      await openArticle(tester, createArticle(score: '9.5'));

      expect(find.text('9.5'), findsOneWidget);
    });

    testWidgets('WB-77: no muestra imagen cuando imageUrl es nulo', (
      tester,
    ) async {
      await openArticle(tester, createArticle(imageUrl: null));

      expect(find.byType(Image), findsNothing);

      expect(find.text('Noticia de prueba LAGUN'), findsOneWidget);
    });

    testWidgets('WB-78: muestra imagen cuando existe una URL', (tester) async {
      await openArticle(
        tester,
        createArticle(imageUrl: 'https://example.invalid/noticia.png'),
      );

      expect(find.byType(Image), findsOneWidget);

      final image = tester.widget<Image>(find.byType(Image).first);

      expect(image.image, isA<NetworkImage>());
    });

    testWidgets('WB-79: permite cerrar el modal de noticia', (tester) async {
      await openArticle(tester, createArticle());

      expect(find.byType(ArticleDetailModal), findsOneWidget);

      await tester.tap(find.text('Cerrar Lectura'));
      await tester.pumpAndSettle();

      expect(find.byType(ArticleDetailModal), findsNothing);

      expect(find.text('ABRIR ARTÍCULO'), findsOneWidget);
    });

    testWidgets('WB-80: el modal utiliza un área desplazable', (tester) async {
      await openArticle(tester, createArticle());

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      expect(
        find.descendant(
          of: find.byType(ArticleDetailModal),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });
  });
}

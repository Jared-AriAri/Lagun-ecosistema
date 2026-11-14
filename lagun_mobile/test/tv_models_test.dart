import 'package:flutter_test/flutter_test.dart';
import 'package:lagun_mobile/models/tv_models.dart';

void main() {
  group('WB-41 a WB-45: modelos de noticias y telemetría', () {
    test('WB-41: TvItem conserva los campos obligatorios', () {
      final item = TvItem(
        id: 'n-001',
        slug: 'noticia-ejemplo',
        type: 'news',
        title: 'Noticia de prueba',
        subtitle: 'Resumen',
        tag: 'NOTICIA',
      );
      expect(item.id, 'n-001');
      expect(item.slug, 'noticia-ejemplo');
      expect(item.type, 'news');
      expect(item.title, 'Noticia de prueba');
      expect(item.subtitle, 'Resumen');
      expect(item.tag, 'NOTICIA');
      expect(item.imageUrl, isNull);
      expect(item.score, isNull);
    });

    test('WB-42: TvItem conserva imagen y puntuación opcionales', () {
      final item = TvItem(
        id: 'r-001',
        slug: 'resena-ejemplo',
        type: 'reviews',
        title: 'Reseña de prueba',
        subtitle: '',
        imageUrl: 'https://example.com/imagen.png',
        tag: 'RESEÑA',
        score: '8/10',
      );
      expect(item.imageUrl, 'https://example.com/imagen.png');
      expect(item.score, '8/10');
    });

    test('WB-43: telemetría normal conserva todos sus valores', () {
      final metrics = TelemetryMetrics(
        readingTimeSec: 120,
        stressLevel: 35,
        sleepQuality: 85,
        needsRest: false,
      );
      expect(metrics.readingTimeSec, 120);
      expect(metrics.stressLevel, 35);
      expect(metrics.sleepQuality, 85);
      expect(metrics.needsRest, isFalse);
    });

    test('WB-44: telemetría con necesidad de descanso', () {
      final metrics = TelemetryMetrics(
        readingTimeSec: 0,
        stressLevel: 87,
        sleepQuality: 25,
        needsRest: true,
      );
      expect(metrics.stressLevel, 87);
      expect(metrics.sleepQuality, 25);
      expect(metrics.needsRest, isTrue);
    });

    test('WB-45: valores límite se conservan sin alteraciones', () {
      final metrics = TelemetryMetrics(
        readingTimeSec: 0,
        stressLevel: 70,
        sleepQuality: 50,
        needsRest: false,
      );
      expect(metrics.readingTimeSec, 0);
      expect(metrics.stressLevel, 70);
      expect(metrics.sleepQuality, 50);
    });
  });
}

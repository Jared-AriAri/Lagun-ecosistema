class TvItem {
  final String id;
  final String slug;
  final String type;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String tag;
  final String? score;

  TvItem({
    required this.id,
    required this.slug,
    required this.type,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.tag,
    this.score,
  });
}

class TelemetryMetrics {
  final int readingTimeSec;
  final int stressLevel;
  final int sleepQuality;
  final bool needsRest;

  TelemetryMetrics({
    required this.readingTimeSec,
    required this.stressLevel,
    required this.sleepQuality,
    required this.needsRest,
  });
}
import 'package:flutter/material.dart';
import '../models/tv_models.dart';

class TelemetryBar extends StatelessWidget {
  final TelemetryMetrics telemetry;
  final bool isConnected;

  const TelemetryBar({
    super.key,
    required this.telemetry,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141024),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem("TIEMPO LECTURA", "${telemetry.readingTimeSec}s", Colors.cyanAccent),
              _buildMetricItem(
                "ESTRÉS",
                "${telemetry.stressLevel}%",
                telemetry.stressLevel > 70 ? Colors.redAccent : Colors.greenAccent,
              ),
              _buildMetricItem("SUEÑO", "${telemetry.sleepQuality}%", Colors.amberAccent),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConnected ? 'LIVE' : 'SYNC',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (telemetry.needsRest)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alerta de Salud: Elevado estrés o bajo descanso. ¡Tómate una pausa!',
                    style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
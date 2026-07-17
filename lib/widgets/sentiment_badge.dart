import 'package:flutter/material.dart';

/// Sentiment badge widget — shows anger score 1-5 with color coding.
class SentimentBadge extends StatelessWidget {
  final int angerScore; // 1..5
  final double size;
  const SentimentBadge({super.key, required this.angerScore, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _describe(angerScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: size),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: size - 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, String, IconData) _describe(int score) {
    switch (score) {
      case 1:
        return (const Color(0xFF10B981), 'Calm', Icons.sentiment_satisfied);
      case 2:
        return (const Color(0xFF84CC16), 'Neutral', Icons.sentiment_neutral);
      case 3:
        return (const Color(0xFFF59E0B), 'Annoyed', Icons.sentiment_dissatisfied);
      case 4:
        return (const Color(0xFFF97316), 'Angry', Icons.sentiment_very_dissatisfied);
      case 5:
      default:
        return (const Color(0xFFEF4444), 'Furious', Icons.whatshot);
    }
  }
}

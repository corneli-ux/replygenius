/// One generated reply option shown to the user in the overlay.
class ReplyVariant {
  final String id;
  final String text;
  final String style; // 'calm' | 'action' | 'empathetic' | etc.
  final String rationale; // why this reply works

  ReplyVariant({
    required this.id,
    required this.text,
    required this.style,
    required this.rationale,
  });

  factory ReplyVariant.fromJson(Map<String, dynamic> json) => ReplyVariant(
        id: json['id'] as String,
        text: json['text'] as String,
        style: json['style'] as String? ?? 'calm',
        rationale: json['rationale'] as String? ?? '',
      );
}

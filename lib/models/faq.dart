/// A single FAQ entry — short question, official answer the AI should lean on.
class FAQ {
  final String id;
  final String question;
  final String answer;
  final DateTime createdAt;

  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FAQ.fromJson(Map<String, dynamic> json) => FAQ(
        id: json['id'] as String,
        question: json['question'] as String,
        answer: json['answer'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

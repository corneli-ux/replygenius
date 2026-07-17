/// Incoming customer message captured from a notification channel.
class CustomerMessage {
  final String id;
  final String channel; // 'whatsapp' | 'sms'
  final String sender; // customer name or phone
  final String text;
  final DateTime receivedAt;

  CustomerMessage({
    required this.id,
    required this.channel,
    required this.sender,
    required this.text,
    required this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel': channel,
        'sender': sender,
        'text': text,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory CustomerMessage.fromJson(Map<String, dynamic> json) => CustomerMessage(
        id: json['id'] as String,
        channel: json['channel'] as String,
        sender: json['sender'] as String,
        text: json['text'] as String,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
      );
}

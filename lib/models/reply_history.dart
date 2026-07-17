/// A saved reply in the history log.
class ReplyHistoryEntry {
  final String id;
  final String channel;
  final String sender;
  final String incomingMessage;
  final String sentReply;
  final int angerScore;
  final DateTime timestamp;

  ReplyHistoryEntry({
    required this.id,
    required this.channel,
    required this.sender,
    required this.incomingMessage,
    required this.sentReply,
    required this.angerScore,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'channel': channel,
        'sender': sender,
        'incoming_message': incomingMessage,
        'sent_reply': sentReply,
        'anger_score': angerScore,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ReplyHistoryEntry.fromMap(Map<String, dynamic> map) =>
      ReplyHistoryEntry(
        id: map['id'] as String,
        channel: map['channel'] as String,
        sender: map['sender'] as String,
        incomingMessage: map['incoming_message'] as String,
        sentReply: map['sent_reply'] as String,
        angerScore: map['anger_score'] as int,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

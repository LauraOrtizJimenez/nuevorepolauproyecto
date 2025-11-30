class EmoteEvent {
  final String gameId;
  final String fromPlayerId;
  final String fromUsername;
  final int emoteCode;
  final DateTime sentAt;

  EmoteEvent({
    required this.gameId,
    required this.fromPlayerId,
    required this.fromUsername,
    required this.emoteCode,
    required this.sentAt,
  });

  factory EmoteEvent.fromJson(Map<String, dynamic> json) {
    return EmoteEvent(
      gameId: json['gameId']?.toString() ?? '',
      fromPlayerId: json['fromPlayerId']?.toString() ?? '',
      fromUsername: (json['fromUsername'] ?? '').toString(),
      emoteCode: json['emoteCode'] ?? 0,
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'fromPlayerId': fromPlayerId,
        'fromUsername': fromUsername,
        'emoteCode': emoteCode,
        'sentAt': sentAt.toIso8601String(),
      };
}

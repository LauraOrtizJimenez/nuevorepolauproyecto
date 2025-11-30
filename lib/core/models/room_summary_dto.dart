import 'dart:convert';

class RoomSummaryDto {
  final String id;
  final String name;
  final int currentPlayers;
  final int maxPlayers;
  final String status;
  final List<String> playerNames;
  final String? gameId;        // 👈 NECESARIO PARA QUE AMBOS JUGADORES ENTREN AL GAME
  final bool isPrivate;        // 🔐 NUEVO

  RoomSummaryDto({
    required this.id,
    required this.name,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.status,
    required this.playerNames,
    this.gameId,
    this.isPrivate = false,
  });

  factory RoomSummaryDto.fromJson(Map<String, dynamic> json) {
    bool parseIsPrivate(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        final v = value.toLowerCase();
        return v == 'true' || v == '1';
      }
      return false;
    }

    return RoomSummaryDto(
      id: (json['id'] ?? json['roomId']).toString(),
      name: (json['name'] ?? json['roomName'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      currentPlayers: (json['currentPlayers'] ?? json['players'] ?? 0) as int,
      maxPlayers: (json['maxPlayers'] ?? json['capacity'] ?? 0) as int,
      playerNames: (json['playerNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      gameId: json['gameId']?.toString(),
      isPrivate: parseIsPrivate(json['isPrivate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
      'playerNames': playerNames,
      'gameId': gameId,
      'isPrivate': isPrivate,
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}

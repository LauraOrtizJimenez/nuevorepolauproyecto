class PlayerStateDto {
  final String id;
  final String username;
  final int position;
  final bool isTurn;

  // 🎨 SKIN (opcionales)
  final String? tokenColorKey;
  final String? tokenIconKey;

  PlayerStateDto({
    required this.id,
    required this.username,
    required this.position,
    required this.isTurn,
    this.tokenColorKey,
    this.tokenIconKey,
  });

  factory PlayerStateDto.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is double) return v != 0.0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return false;
    }

    dynamic isTurnRaw = json['isCurrentTurn'] ??
        json['isTurn'] ??
        json['turn'] ??
        json['current'] ??
        json['active'];

    // BACKEND ALWAYS USES playerId
    final String idVal = (json['playerId'] ?? json['id'])?.toString() ?? '';

    final String usernameVal =
        (json['username'] ?? json['name'] ?? json['user'] ?? '')
            .toString()
            .trim();

    int positionVal = 0;
    final posRaw = json['position'] ?? json['pos'] ?? json['posicion'];
    if (posRaw is int) {
      positionVal = posRaw;
    } else if (posRaw is double) {
      positionVal = posRaw.toInt();
    } else if (posRaw is String) {
      positionVal = int.tryParse(posRaw) ?? 0;
    }

    // 🎨 Leer claves de skin si el backend las manda
    final String? colorKey =
        (json['tokenColorKey'] ?? json['colorKey']) as String?;
    final String? iconKey =
        (json['tokenIconKey'] ?? json['iconKey']) as String?;

    return PlayerStateDto(
      id: idVal,
      username: usernameVal,
      position: positionVal,
      isTurn: parseBool(isTurnRaw),
      tokenColorKey: colorKey,
      tokenIconKey: iconKey,
    );
  }
}

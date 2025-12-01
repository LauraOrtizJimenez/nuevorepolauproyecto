class AuthResponseDto {
  final String token;
  final String username;
  final String userId;
  final int wins;
  final int coins; // 👈 nuevo

  AuthResponseDto({
    required this.token,
    required this.username,
    required this.userId,
    this.wins = 0,
    this.coins = 0, // 👈 nuevo
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      token: json['token'] as String? ?? '',
      username: json['username'] as String? ?? '',
      userId: (json['userId'] ?? json['id'])?.toString() ?? '',
      wins: json['wins'] as int? ??
          json['gamesWon'] as int? ??
          0,
      coins: json['coins'] as int? ?? 0, // 👈 viene del backend
    );
  }
}

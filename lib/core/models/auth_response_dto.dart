class AuthResponseDto {
  final String token;
  final String username;
  final String userId;
  final int? wins;

  AuthResponseDto({
    required this.token, 
    required this.username, 
    required this.userId,
    this.wins,
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      token: json['token'] as String? ?? '',
      username: json['username'] as String? ?? '',
      userId: (json['userId'] ?? json['id'])?.toString() ?? '',
      wins: json['wins'] as int? ?? json['gamesWon'] as int? ?? 0,
    );
  }
}
//

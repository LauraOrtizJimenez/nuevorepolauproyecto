import '../api_client.dart';
import '../models/auth_response_dto.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  /// Login: devuelve AuthResponseDto (token, username, userId, wins, coins)
  Future<AuthResponseDto> login(String username, String password) async {
    final body = {'username': username, 'password': password};
    final resp = await _client.postJson('/api/Auth/login', body);

    if (resp is! Map) {
      // El backend debería devolver un JSON objeto; si no, lanzamos error legible
      throw Exception('Respuesta inesperada del servidor en login: $resp');
    }

    return AuthResponseDto.fromJson(
      Map<String, dynamic>.from(resp),
    );
  }

  /// Register: si tu backend también devuelve el mismo DTO, usamos AuthResponseDto.
  /// Si solo devuelve un mensaje simple, puedes cambiar el tipo de retorno a void o Map.
  Future<AuthResponseDto> register(
      String username, String email, String password) async {
    final body = {
      'username': username,
      'email': email,
      'password': password,
    };
    final resp = await _client.postJson('/api/Auth/register', body);

    if (resp is! Map) {
      throw Exception('Respuesta inesperada del servidor en register: $resp');
    }

    return AuthResponseDto.fromJson(
      Map<String, dynamic>.from(resp),
    );
  }
}

// lib/core/services/lobby_service.dart
import 'package:profesoresymatones/core/api_client.dart';
import 'package:profesoresymatones/core/models/room_summary_dto.dart';

class LobbyService {
  final ApiClient _client = ApiClient();

  /// Obtener salas disponibles (el backend ya filtra públicas)
  Future<List<RoomSummaryDto>> getRooms() async {
    final resp = await _client.getJson('/api/Lobby/rooms');

    if (resp is List) {
      return resp
          .map((e) => RoomSummaryDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }

    throw Exception('Formato inesperado al obtener rooms: $resp');
  }

  /// Crear sala (pública / privada)
  Future<RoomSummaryDto> createRoom({
    required String name,
    required int maxPlayers,
    required bool isPrivate,
    String? accessCode,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'maxPlayers': maxPlayers,
      'isPrivate': isPrivate,
    };

    if (isPrivate && accessCode != null && accessCode.isNotEmpty) {
      body['accessCode'] = accessCode;
    }

    final resp = await _client.postJson('/api/Lobby/rooms', body);

    if (resp is Map) {
      return RoomSummaryDto.fromJson(
        Map<String, dynamic>.from(resp),
      );
    }

    throw Exception('Formato inesperado al crear room: $resp');
  }

  /// Unirse a sala (si es privada, se manda accessCode)
  Future<RoomSummaryDto> joinRoom({
    required String roomId,
    String? accessCode,
  }) async {
    final body = <String, dynamic>{
      'roomId': int.parse(roomId),
    };

    if (accessCode != null && accessCode.isNotEmpty) {
      body['accessCode'] = accessCode;
    }

    final resp = await _client.postJson('/api/Lobby/rooms/join', body);

    // El backend devuelve: { message, room: { ... } }
    if (resp is Map && resp['room'] is Map) {
      return RoomSummaryDto.fromJson(
        Map<String, dynamic>.from(resp['room'] as Map),
      );
    }

    // Por si algún caso devuelve directamente el room
    if (resp is Map) {
      return RoomSummaryDto.fromJson(
        Map<String, dynamic>.from(resp),
      );
    }

    throw Exception('Formato inesperado al unirse a room: $resp');
  }
}

import '../api_client.dart';
import '../models/token_skin_store_item.dart';

class SkinsService {
  final ApiClient _apiClient = ApiClient();

  /// LISTA DE SKINS DE LA TIENDA
  /// Usa el endpoint existente: GET /api/Skins
  Future<List<TokenSkinStoreItem>> getStoreSkins() async {
    final data = await _apiClient.getJson('/api/Skins');

    // Por si tu backend envuelve en { data: [...] }
    final listJson =
        (data is Map && data['data'] is List) ? data['data'] : data;

    if (listJson is! List) {
      throw Exception('Formato inesperado al leer /api/Skins');
    }

    return listJson
        .map((e) => TokenSkinStoreItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// SKINS QUE YA TIENE EL USUARIO
  /// Usa: GET /api/Skins/user
  Future<List<TokenSkinStoreItem>> getOwnedSkins() async {
    final data = await _apiClient.getJson('/api/Skins/user');

    dynamic listJson;

    if (data is List) {
      // Respuesta directa: [ {...}, {...} ]
      listJson = data;
    } else if (data is Map) {
      // Intentar varios "wrappers" típicos
      if (data['data'] is List) {
        listJson = data['data'];
      } else if (data['skins'] is List) {
        listJson = data['skins'];
      } else if (data['ownedSkins'] is List) {
        listJson = data['ownedSkins'];
      } else {
        // Si no viene lista, lo interpretamos como "no tienes skins"
        listJson = const <dynamic>[];
      }
    } else {
      // Cualquier otra cosa => lista vacía
      listJson = const <dynamic>[];
    }

    return (listJson as List)
        .map((e) => TokenSkinStoreItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// COMPRAR SKIN
  /// Usa: POST /api/Skins/purchase/{skinId}
  Future<void> buySkin(int skinId) async {
    await _apiClient.postJson(
      '/api/Skins/purchase/$skinId',
      <String, dynamic>{}, // body vacío
    );
  }

  /// SELECCIONAR SKIN
  /// Usa: POST /api/Skins/select/{skinId}
  Future<void> selectSkin(int skinId) async {
    await _apiClient.postJson(
      '/api/Skins/select/$skinId',
      <String, dynamic>{},
    );
  }
}

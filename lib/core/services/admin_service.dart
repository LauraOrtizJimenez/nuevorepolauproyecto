import '../api_client.dart';

class AdminService {
  final ApiClient _apiClient = ApiClient();

  /// 🪙 Dar monedas a un usuario
  ///
  /// (Luego en backend crear:
  ///  POST /api/admin/give-coins
  ///  body { userId, amount })
  Future<void> giveCoins({
    required int userId,
    required int amount,
  }) async {
    final body = {
      'userId': userId,
      'amount': amount,
    };

    await _apiClient.postJson('/api/admin/give-coins', body);
  }

  /// 🎨 Crear una nueva skin en la tienda
  ///
  /// Usa el endpoint EXISTENTE: POST /api/Skins
  /// (ajusta nombres de propiedades si tu DTO usa otros)
  Future<void> createSkin({
    required String name,
    required String colorKey,
    required String iconKey,
    required int priceCoins,
    bool isActive = true,
  }) async {
    final body = {
      'name': name,
      'colorKey': colorKey,
      'iconKey': iconKey,
      'priceCoins': priceCoins,
      'isActive': isActive,
    };

    await _apiClient.postJson('/api/Skins', body);
  }
}

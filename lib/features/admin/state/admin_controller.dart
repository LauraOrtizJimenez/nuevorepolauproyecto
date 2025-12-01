import 'package:flutter/foundation.dart';
import '../../../core/services/admin_service.dart';

class AdminController extends ChangeNotifier {
  final AdminService _service;

  AdminController(this._service);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String? _success;
  String? get success => _success;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void _setSuccess(String? value) {
    _success = value;
    notifyListeners();
  }

  /// 🪙 Dar monedas a un usuario
  Future<void> giveCoins({
    required int userId,
    required int amount,
  }) async {
    if (amount == 0) {
      _setError('El monto no puede ser 0');
      return;
    }

    _setLoading(true);
    _setError(null);
    _setSuccess(null);

    try {
      await _service.giveCoins(userId: userId, amount: amount);
      _setSuccess('Se han asignado $amount coins al usuario $userId');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// 🎨 Crear una nueva skin para la tienda
  Future<void> createSkin({
    required String name,
    required String colorKey,
    required String iconKey,
    required int priceCoins,
    bool isActive = true,
  }) async {
    if (name.trim().isEmpty) {
      _setError('El nombre de la skin es obligatorio');
      return;
    }
    if (priceCoins < 0) {
      _setError('El precio no puede ser negativo');
      return;
    }

    _setLoading(true);
    _setError(null);
    _setSuccess(null);

    try {
      await _service.createSkin(
        name: name,
        colorKey: colorKey,
        iconKey: iconKey,
        priceCoins: priceCoins,
        isActive: isActive,
      );
      _setSuccess('Skin "$name" creada correctamente');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/models/token_skin_store_item.dart';
import '../../../core/services/skins_service.dart';

class SkinsStoreController extends ChangeNotifier {
  final SkinsService _service;

  SkinsStoreController(this._service);

  bool _loading = false;
  bool get loading => _loading;

  List<TokenSkinStoreItem> _items = [];
  List<TokenSkinStoreItem> get items => _items;

  int _coins = 0;
  int get coins => _coins;

  String? _error;
  String? get error => _error;

  void setCoins(int value) {
    _coins = value;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// 🛒 Skins visibles en la TIENDA (catálogo)
  Future<void> loadStore() async {
    _setLoading(true);
    _setError(null);
    try {
      _items = await _service.getStoreSkins();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// 🎒 Skins que YA son del usuario (para "Mis skins")
  Future<void> loadOwnedSkins() async {
    _setLoading(true);
    _setError(null);
    try {
      _items = await _service.getOwnedSkins();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> buySkin(TokenSkinStoreItem item) async {
    if (item.isOwned) return;
    if (_coins < item.priceCoins) {
      _setError('No tienes suficientes monedas');
      return;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _service.buySkin(item.id);
      _coins -= item.priceCoins;

      // recargamos la tienda (no owned)
      await loadStore();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectSkin(TokenSkinStoreItem item) async {
    // ❌ Ya no validamos item.isOwned aquí.
    // El backend se encarga de validar si la skin pertenece al usuario.

    _setLoading(true);
    _setError(null);
    try {
      await _service.selectSkin(item.id);

      // si estás en tienda u owned, la recarga marcará la skin seleccionada
      if (_items.any((e) => !e.isOwned)) {
        await loadStore();
      } else {
        await loadOwnedSkins();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}

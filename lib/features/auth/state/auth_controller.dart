import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/models/auth_response_dto.dart';
import '../../../core/services/user_service.dart'; // 👈 NUEVO

class AuthController extends ChangeNotifier {
  final AuthService _service = AuthService();
  final UserService _userService = UserService(); // 👈 NUEVO

  bool _loading = false;
  String? _token;
  String? _username;
  String? _userId;
  int _wins = 0;
  int _coins = 0;

  // 🎨 Skin seleccionada (opcional)
  String? _selectedColorKey;
  String? _selectedIconKey;

  String? error;

  bool get loading => _loading;
  String? get token => _token;
  String? get username => _username;
  String? get userId => _userId;
  int get wins => _wins;
  int get coins => _coins;

  String? get selectedColorKey => _selectedColorKey;
  String? get selectedIconKey => _selectedIconKey;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  AuthController() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _username = prefs.getString('username');
    _userId = prefs.getString('userId');
    _wins = prefs.getInt('wins') ?? 0;
    _coins = prefs.getInt('coins') ?? 0;

    // 🎨 cargar skin seleccionada si existiera
    final cKey = prefs.getString('selectedColorKey');
    final iKey = prefs.getString('selectedIconKey');
    _selectedColorKey = (cKey != null && cKey.isNotEmpty) ? cKey : null;
    _selectedIconKey = (iKey != null && iKey.isNotEmpty) ? iKey : null;

    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    error = null;
    notifyListeners();

    try {
      final AuthResponseDto dto = await _service.login(username, password);

      _token = dto.token;
      _username = dto.username;
      _userId = dto.userId;
      _wins = dto.wins;
      _coins = dto.coins;

      // Opcional: al hacer login, por ahora limpiamos la skin local
      _selectedColorKey = null;
      _selectedIconKey = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token ?? '');
      await prefs.setString('username', _username ?? '');
      await prefs.setString('userId', _userId ?? '');
      await prefs.setInt('wins', _wins);
      await prefs.setInt('coins', _coins);
      await prefs.remove('selectedColorKey');
      await prefs.remove('selectedIconKey');

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _loading = true;
    error = null;
    notifyListeners();

    try {
      final AuthResponseDto dto =
          await _service.register(username, email, password);

      _token = dto.token;
      _username = dto.username;
      _userId = dto.userId;
      _wins = dto.wins;
      _coins = dto.coins;

      _selectedColorKey = null;
      _selectedIconKey = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token ?? '');
      await prefs.setString('username', _username ?? '');
      await prefs.setString('userId', _userId ?? '');
      await prefs.setInt('wins', _wins);
      await prefs.setInt('coins', _coins);
      await prefs.remove('selectedColorKey');
      await prefs.remove('selectedIconKey');

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// 🏆 Incremento local de partidas ganadas (fallback simple)
  Future<void> incrementWins() async {
    _wins += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wins', _wins);
    notifyListeners();
  }

  Future<void> setCoins(int value) async {
    _coins = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', _coins);
    notifyListeners();
  }

  /// 🔄 Refrescar wins / coins desde el backend (`GET /api/Users/me`)
  ///
  /// Útil después de:
  ///  - que el usuario gane una partida (backend suma wins/coins)
  ///  - que cambies las coins en la BD a mano
  ///  - abrir la tienda o el lobby y querer ver el valor real del servidor
  Future<void> refreshProfile() async {
    if (!isLoggedIn) return;

    try {
      final data = await _userService.getMe(); // lo creamos en `user_service.dart`

      // El backend puede usar GamesWon / gamesWon y Coins / coins
      final rawWins = data['gamesWon'] ?? data['GamesWon'] ?? _wins;
      final rawCoins = data['coins'] ?? data['Coins'] ?? _coins;

      _wins = rawWins is int ? rawWins : int.tryParse(rawWins.toString()) ?? _wins;
      _coins = rawCoins is int ? rawCoins : int.tryParse(rawCoins.toString()) ?? _coins;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('wins', _wins);
      await prefs.setInt('coins', _coins);

      notifyListeners();
    } catch (e) {
      // Si falla, no rompemos la app: simplemente dejamos los valores locales
      debugPrint('Error al refrescar perfil: $e');
    }
  }

  // 🎨 Guardar skin seleccionada (cuando el usuario pulsa "Usar" en la tienda)
  Future<void> setSelectedSkin({
    String? colorKey,
    String? iconKey,
  }) async {
    _selectedColorKey = colorKey;
    _selectedIconKey = iconKey;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedColorKey', colorKey ?? '');
    await prefs.setString('selectedIconKey', iconKey ?? '');
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');
    await prefs.remove('userId');
    await prefs.remove('wins');
    await prefs.remove('coins');
    await prefs.remove('selectedColorKey');
    await prefs.remove('selectedIconKey');

    _token = null;
    _username = null;
    _userId = null;
    _wins = 0;
    _coins = 0;
    _selectedColorKey = null;
    _selectedIconKey = null;

    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/state/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';

import 'features/lobby/presentation/lobby_page.dart';
import 'features/lobby/presentation/room_detail_page.dart';
import 'features/lobby/presentation/waiting_room_page.dart'
    as lobby_waiting; // 👈 alias para evitar ambigüedades

// 👉 Página del tablero de juego
import 'features/game/presentation/game_board_page.dart';

// 👉 Controlador de juego (alias)
import 'features/game/state/game_controller.dart' as game_state;

import 'features/profile/presentation/profile_page.dart';
import 'features/leaderboard/presentation/leaderboard_page.dart';
import 'features/lobby/state/lobby_controller.dart';
import 'features/profile/state/profile_controller.dart';
import 'features/leaderboard/state/leaderboard_controller.dart';

// 🛒 tienda de skins
import 'features/profile/presentation/shop_page.dart';

// 🛠 panel admin (opcional, si ya lo creaste)
import 'features/admin/presentation/admin_panel_page.dart';

import 'theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => LobbyController()),
        ChangeNotifierProvider(create: (_) => game_state.GameController()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => LeaderboardController()),
      ],
      child: MaterialApp(
        title: 'Profesores y Matones',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/lobby': (_) => const LobbyPage(),
          '/profile': (_) => const ProfilePage(),
          '/leaderboard': (_) => const LeaderboardPage(),

          // 🛒 TIENDA → ahora sin initialCoins, el ShopPage lee las coins desde AuthController
          '/shop': (_) => const ShopPage(),

          // 🛠 Panel admin (solo la cuenta especial lo verá por el chequeo interno)
          '/admin': (_) => const AdminPanelPage(),
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';

          // Rutas de rooms (lobby)
          if (name.startsWith('/rooms/')) {
            final sub = name.split('/rooms/').last;

            if (sub.contains('/waiting')) {
              final roomId =
                  sub.split('/waiting').first.replaceAll(RegExp(r'^/'), '');
              return MaterialPageRoute(
                builder: (_) =>
                    lobby_waiting.WaitingRoomPage(roomId: roomId),
              );
            }

            final roomId = sub;
            return MaterialPageRoute(
              builder: (_) => RoomDetailPage(roomId: roomId),
            );
          }

          // Ruta de juego: /game/123
          if (name.startsWith('/game/')) {
            final gameId = name.split('/game/').last;
            return MaterialPageRoute(
              builder: (_) => GameBoardPage(gameId: gameId),
            );
          }

          return null;
        },
      ),
    );
  }
}

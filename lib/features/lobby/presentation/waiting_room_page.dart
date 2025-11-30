import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/lobby_controller.dart';
import '../../../core/models/room_summary_dto.dart';
import '../../../core/services/game_service.dart';

import 'package:profesoresymatones/core/signalr_client.dart';

import '../../auth/state/auth_controller.dart';
import '../../game/presentation/game_board_page.dart';

class WaitingRoomPage extends StatefulWidget {
  final String roomId;

  const WaitingRoomPage({super.key, required this.roomId});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  final GameService _gameService = GameService();

  RoomSummaryDto? _room;
  bool _startingGame = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();

    // Cargar una vez al entrar
    _loadRoomOnce();

    // Configurar SignalR + polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSignalRForLobby();
      _startPollingRoom();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();

    final client = SignalRClient();
    final idInt = int.tryParse(widget.roomId);

    if (client.isConnected && idInt != null) {
      client.invoke('LeaveLobbyGroup', args: [idInt]).catchError((_) {});
    }

    super.dispose();
  }

  // ------------------------------------------------------------
  // POLLING CADA 1s
  // ------------------------------------------------------------
  void _startPollingRoom() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadRoomOnce(),
    );
  }

  // ------------------------------------------------------------
  // SIGNALR EVENTOS DEL LOBBY
  // ------------------------------------------------------------
  Future<void> _initSignalRForLobby() async {
    final auth = context.read<AuthController>();
    final token = auth.token;

    final client = SignalRClient();
    final roomIdInt = int.tryParse(widget.roomId);

    try {
      if (!client.isConnected) {
        await client.connect(accessToken: token);
      }

      if (roomIdInt != null) {
        await client.invoke('JoinLobbyGroup', args: [roomIdInt]);
      }

      client.on('LobbyUpdated', (_) => _loadRoomOnce());
      client.on('LobbyPlayerJoined', (_) => _loadRoomOnce());
      client.on('LobbyPlayerLeft', (_) => _loadRoomOnce());
    } catch (e) {
      dev.log("[Lobby] SignalR error: $e", name: "WaitingRoom");
    }
  }

  // ------------------------------------------------------------
  // CARGAR SALA (HTTP GET)
  // ------------------------------------------------------------
  Future<void> _loadRoomOnce() async {
    try {
      final lobby = context.read<LobbyController>();
      final room = await lobby.getRoomById(widget.roomId);

      if (!mounted) return;

      if (room == null) {
        dev.log("[Lobby] GET returned null", name: "WaitingRoom");
        return;
      }

      setState(() {
        _room = room; // dato fresco del backend
      });

      dev.log("[Lobby] Loaded room: ${room.playerNames.length} players",
          name: "WaitingRoom");
    } catch (e) {
      dev.log("[Lobby] Error loading room: $e", name: "WaitingRoom");
    }
  }

  // ------------------------------------------------------------
  // CREAR / ENTRAR AL JUEGO (SOLO HOST CREA)
  // ------------------------------------------------------------
  Future<void> _hostCreateAndEnterGame(RoomSummaryDto room) async {
    if (_startingGame) return;

    if (room.playerNames.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Se necesitan al menos 2 jugadores")),
      );
      return;
    }

    setState(() => _startingGame = true);

    try {
      final game = await _gameService.createGame(roomId: room.id.toString());

      if (!mounted) return;
      _pollTimer?.cancel();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GameBoardPage(gameId: game.id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _startingGame = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo entrar a la partida"),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // BUILD UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyController>();
    final auth = context.read<AuthController>();

    // Usamos SIEMPRE primero el valor fresco del backend
    RoomSummaryDto? room = _room;

    // Respaldo: lista general del lobby
    if (room == null && lobby.rooms.isNotEmpty) {
      try {
        room = lobby.rooms.firstWhere(
          (r) => r.id.toString() == widget.roomId,
        );
      } catch (_) {}
    }

    // Si aún no hay datos, mostramos fondo+loader
    if (room == null) {
      return Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    final players = room.playerNames;
    final maxPlayers = room.maxPlayers;
    final myUsername = auth.username ?? "";

    final bool isHost = players.isNotEmpty &&
        players.first.trim().toLowerCase() ==
            myUsername.trim().toLowerCase();

    // ¿La sala ya tiene un juego creado?
    final bool hasGame =
        room.gameId != null && room.gameId!.trim().isNotEmpty;

    // Texto del botón principal
    final String mainButtonText = hasGame
        ? "Entrar a la partida"
        : (isHost
            ? "Crear y entrar a la partida"
            : "Esperando a que el anfitrión inicie");

    // ¿Está habilitado el botón?
    final bool canPressMainButton =
        hasGame || (isHost && !_startingGame);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 🔙 volver SIEMPRE al lobby
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/lobby',
              (route) => false,
            );
          },
        ),
        title: const Text("Sala de espera"),
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _buildCardContent(
                    context: context,
                    room: room,
                    players: players,
                    maxPlayers: maxPlayers,
                    myUsername: myUsername,
                    isHost: isHost,
                    hasGame: hasGame,
                    mainButtonText: mainButtonText,
                    canPressMainButton: canPressMainButton,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  //  FONDO TIPO JUEGO
  // ------------------------------------------------------------
  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF065A4B), Color(0xFF044339)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 30,
          child: _softIcon(Icons.meeting_room_rounded, 70),
        ),
        Positioned(
          top: 140,
          right: 60,
          child: _softIcon(Icons.groups_rounded, 70),
        ),
        Positioned(
          bottom: 80,
          left: 60,
          child: _softIcon(Icons.casino_rounded, 80),
        ),
        Positioned(
          bottom: 40,
          right: 80,
          child: _softIcon(Icons.timer_rounded, 70),
        ),
      ],
    );
  }

  Widget _softIcon(IconData icon, double size) {
    return Icon(
      icon,
      size: size,
      color: Colors.white.withOpacity(0.06),
    );
  }

  // ------------------------------------------------------------
  //  TARJETA PRINCIPAL
  // ------------------------------------------------------------
  Widget _buildCardContent({
    required BuildContext context,
    required RoomSummaryDto room,
    required List<String> players,
    required int maxPlayers,
    required String myUsername,
    required bool isHost,
    required bool hasGame,
    required String mainButtonText,
    required bool canPressMainButton,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.97),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER SALA
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0DBA99),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Sala ${room.id}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065A4B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.green.withOpacity(0.12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 16,
                        color: Colors.green[800],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${players.length} / $maxPlayers",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // LISTA DE JUGADORES
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Jugadores en la sala",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 160,
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (_, i) {
                  final name = players[i];
                  final isMe = name.trim().toLowerCase() ==
                      myUsername.trim().toLowerCase();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4A90E2),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(name),
                    subtitle: isMe ? const Text("Tú") : null,
                    trailing: isMe && isHost
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0DBA99)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              "Anfitrión",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF065A4B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // TEXTO DE ESTADO
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hasGame
                    ? "La partida ya fue creada. Puedes entrar cuando quieras."
                    : (isHost
                        ? "Cuando haya al menos 2 jugadores, puedes iniciar la partida."
                        : "Espera a que el anfitrión cree la partida."),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // BOTONES
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loadRoomOnce,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Actualizar"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !canPressMainButton
                          ? Colors.grey.shade500
                          : const Color(0xFF0DBA99),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: !_startingGame && canPressMainButton
                        ? () {
                            if (hasGame) {
                              // Ya existe game → cualquier jugador entra al board
                              final gameId = room.gameId!;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GameBoardPage(gameId: gameId),
                                ),
                              );
                            } else {
                              // No existe game → sólo host crea
                              if (isHost) {
                                _hostCreateAndEnterGame(room);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Sólo el anfitrión puede crear la partida"),
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    child: _startingGame
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            mainButtonText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 🔙 botón extra para volver al lobby
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/lobby',
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.meeting_room_outlined),
                label: const Text("Volver al lobby"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

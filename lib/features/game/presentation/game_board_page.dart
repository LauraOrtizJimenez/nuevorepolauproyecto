// -------------------------------------------------------------
// GameBoardPage.dart  (VERSIÓN LIMPIA + EMOTES)
// -------------------------------------------------------------

import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/state/auth_controller.dart';

import '../state/game_controller.dart';
import 'game_board_widget.dart';
import '../../auth/presentation/logout_button.dart';
import '../../../core/models/profesor_question_dto.dart';

class GameBoardPage extends StatefulWidget {
  final String gameId;
  const GameBoardPage({super.key, required this.gameId});

  @override
  State<GameBoardPage> createState() => _GameBoardPageState();
}

class _GameBoardPageState extends State<GameBoardPage>
    with TickerProviderStateMixin {
  static const Color _baseGreen = Color(0xFF065A4B);

  // Animación del dado (zoom)
  late final AnimationController _diceController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _diceScale =
      CurvedAnimation(parent: _diceController, curve: Curves.elasticOut);

  bool _showDice = false;
  int? _diceNumber;
  bool _diceRolling = false;
  double _diceTilt = 0.0;

  // Overlay (matón / profesor especial)
  bool _showSpecialOverlay = false;
  String? _specialMessage;

  // Aggressive reload
  bool _waitingForPlayers = false;
  Timer? _aggressiveReloadTimer;
  int _aggressiveReloadAttempts = 0;

  // Track if profesor dialog is currently showing
  bool _profesorDialogShowing = false;
  String? _lastShownQuestionId;

  // Tracking para detectar rendición de jugadores (IDs como String)
  List<String> _lastPlayerIds = [];
  Map<String, String> _lastPlayerNames = {};

  // Tracking para mensaje de victoria
  String? _lastGameStatus;

  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<GameController>(context, listen: false);

    // Esperar login antes de cargar game
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _clearSnackBars();

      final auth = Provider.of<AuthController>(context, listen: false);
      int attempts = 0;
      while (!auth.isLoggedIn && attempts < 15) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
      if (widget.gameId == "new") {
        await ctrl.createOrJoinGame();
      } else {
        await ctrl.loadGame(widget.gameId);
      }
    });

    // Listener: detección de rendición + eventos especiales tipo "Matón"
    ctrl.addListener(_onControllerChanged);

    try {
      ctrl.startPollingGame();
    } catch (_) {}

    ctrl.addListener(_maybeStartAggressiveReload);
  }

  // Limpia SnackBars que vengan de otras pantallas
  void _clearSnackBars() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  void _maybeStartAggressiveReload() {
    final ctrl = Provider.of<GameController>(context, listen: false);

    try {
      if (ctrl.game != null && ctrl.game!.players.isEmpty) {
        if (!_waitingForPlayers) {
          _waitingForPlayers = true;
          _aggressiveReloadAttempts = 0;

          _aggressiveReloadTimer?.cancel();
          _aggressiveReloadTimer = Timer.periodic(
            const Duration(milliseconds: 400),
            (t) async {
              _aggressiveReloadAttempts++;
              try {
                await ctrl.loadGame(ctrl.game!.id);
              } catch (_) {}

              if (!mounted) return;

              if (ctrl.game == null ||
                  ctrl.game!.players.isNotEmpty ||
                  _aggressiveReloadAttempts >= 12) {
                _aggressiveReloadTimer?.cancel();
                _aggressiveReloadTimer = null;
                _waitingForPlayers = false;
                if (mounted) setState(() {});
              } else {
                if (mounted) setState(() {});
              }
            },
          );
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _clearSnackBars();

    final ctrl = Provider.of<GameController>(context);
    final bool offlineMode = !ctrl.signalRAvailable;

    // Si llega pregunta → mostrar dialogo (solo una vez por pregunta)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ctrl.currentQuestion != null &&
          !_profesorDialogShowing &&
          _lastShownQuestionId != ctrl.currentQuestion!.questionId) {
        _profesorDialogShowing = true;
        _lastShownQuestionId = ctrl.currentQuestion!.questionId;
        final question = ctrl.currentQuestion!;
        // Limpiar INMEDIATAMENTE para evitar duplicados
        ctrl.clearCurrentQuestion();
        await _showProfesorQuestionDialog(question);
        _profesorDialogShowing = false;
      }
    });

    final game = ctrl.game;
    final players = game?.players ?? [];
    final snakes = game?.snakes ?? [];
    final ladders = game?.ladders ?? [];
    final gameId = game?.id ?? "";
    final gameStatus = game?.status ?? "";

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.casino_rounded, size: 22),
            const SizedBox(width: 8),
            const Text("Partida"),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Ver tablero en grande",
            icon: const Icon(Icons.open_in_full),
            onPressed: () {
              if (ctrl.game != null) _openFullScreenBoard(ctrl);
            },
          ),
          const LogoutButton(),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                if (offlineMode)
                  Consumer<GameController>(builder: (ctx, c, _) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100.withOpacity(0.95),
                        border: const Border(
                          bottom: BorderSide(color: Colors.orange, width: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.signal_wifi_off,
                              color: Colors.brown),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Problemas de conexión. Intentando mantener la partida activa.",
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.brown,
                              side: const BorderSide(color: Colors.brown),
                            ),
                            onPressed: () async {
                              final ok = await c.tryReconnectSignalR();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? "Conexión restablecida"
                                        : "No se pudo reconectar",
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    );
                  }),

                // Header superior con info de partida
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0DBA99),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gameId.isNotEmpty ? "Partida $gameId" : "Partida",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              gameStatus.isNotEmpty
                                  ? "Estado: $gameStatus"
                                  : "Esperando actualización...",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.how_to_reg,
                                size: 16, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              ctrl.currentTurnUsername.isNotEmpty
                                  ? "Turno: ${ctrl.currentTurnUsername}"
                                  : "Turno: —",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        // --------------------------------------------------
                        // CONTENIDO PRINCIPAL (TABLERO + LAYOUT)
                        // --------------------------------------------------
                        LayoutBuilder(builder: (ctx, constraints) {
                          final large = constraints.maxWidth >= 1000;

                          if (!ctrl.loading && ctrl.game == null) {
                            return const Center(
                              child: Text(
                                "No hay partida cargada",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }

                          // -----------------------
                          // TABLERO
                          // -----------------------
                          Widget boardCard = Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: large
                                      ? constraints.maxWidth * 0.80
                                      : constraints.maxWidth,
                                  maxHeight: constraints.maxHeight * 0.9,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    color: const Color(0xFFEFF9F5),
                                    child: InteractiveViewer(
                                      panEnabled: true,
                                      scaleEnabled: true,
                                      boundaryMargin: const EdgeInsets.all(40),
                                      minScale: 0.6,
                                      maxScale: 3.5,
                                      child: Center(
                                        child: GameBoardWidget(
                                          players: players,
                                          snakes: snakes,
                                          ladders: ladders,
                                          // Animación del tablero
                                          animatePlayerId:
                                              (ctrl.lastMoveResult?.diceValue ?? 0) > 0
                                                  ? ctrl.lastMovePlayerId
                                                  : null,
                                          animateSteps:
                                              (ctrl.lastMoveResult?.diceValue ?? 0) > 0
                                                  ? ctrl.lastMoveResult?.diceValue
                                                  : null,
                                          onAnimationComplete: () {
                                            final c =
                                                Provider.of<GameController>(
                                                    context,
                                                    listen: false);
                                            if (c.hasPendingSimulatedGame()) {
                                              c.applyPendingSimulatedGame();
                                              c.lastMoveSimulated = false;
                                              c.lastMovePlayerId = null;
                                              c.lastMoveResult = null;
                                            } else if (c.game != null) {
                                              Future.microtask(() =>
                                                  c.loadGame(c.game!.id));
                                              c.lastMovePlayerId = null;
                                              c.lastMoveResult = null;
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );

                          Widget playersList = Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.groups_rounded,
                                            color: Colors.white70, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          "Jugadores",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...players.map(
                                      (p) => Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  const Color(0xFF0DBA99),
                                              child: Text(
                                                p.username.isNotEmpty
                                                    ? p.username[0]
                                                        .toUpperCase()
                                                    : "?",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                p.username,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            if (p.isTurn)
                                              const Icon(
                                                Icons.campaign,
                                                color: Colors.greenAccent,
                                                size: 18,
                                              ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.35),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                "${p.position}",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          // ------------- COLUMNA DE ACCIONES + EMOTES -------------
                          Widget actionsColumn = Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!ctrl.isMyTurn)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Text(
                                        "Turno de: ${ctrl.currentTurnUsername}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  _buildGameButton(
                                    text: "Tirar dado",
                                    icon: Icons.casino_rounded,
                                    enabled: !(ctrl.loading ||
                                        ctrl.waitingForMove ||
                                        !(ctrl.isMyTurn ||
                                            (ctrl.simulateEnabled &&
                                                !ctrl.signalRAvailable) ||
                                            ctrl.forceEnableRoll)),
                                    loading: ctrl.waitingForMove,
                                    onTap: () => _handleRoll(ctrl),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildGameButton(
                                    text: "Abandonar partida",
                                    icon: Icons.flag_rounded,
                                    color: Colors.red.shade500,
                                    enabled: !ctrl.loading,
                                    onTap: () async {
                                      final ok = await ctrl.surrender();
                                      if (ok) {
                                        if (!mounted) return;
                                        Navigator.pushReplacementNamed(
                                            context, "/lobby");
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "No se pudo abandonar la partida",
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    onPressed:
                                        (game == null || gameId.isEmpty)
                                            ? null
                                            : () async {
                                                await ctrl.loadGame(gameId);
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content:
                                                        Text("Partida actualizada"),
                                                  ),
                                                );
                                              },
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text(
                                      "Actualizar",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(
                                    color: Colors.white.withOpacity(0.35),
                                    height: 18,
                                  ),
                                  const SizedBox(height: 4),
                                  // ---------- EMOTES UI ----------
                                  const Text(
                                    "Reacciones",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildEmoteButton(ctrl, 0),
                                      _buildEmoteButton(ctrl, 1),
                                      _buildEmoteButton(ctrl, 2),
                                      _buildEmoteButton(ctrl, 3),
                                      _buildEmoteButton(ctrl, 4),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          Widget boardOverlay = Stack(
                            children: [
                              Center(child: boardCard),
                              if (_waitingForPlayers)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black45,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 12),
                                            Text(
                                              "Esperando sincronización de jugadores...",
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );

                          if (large) {
                            return Row(
                              children: [
                                SizedBox(width: 190, child: playersList),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: boardOverlay,
                                ),
                                const SizedBox(width: 12),
                                SizedBox(width: 220, child: actionsColumn),
                              ],
                            );
                          }

                          // ---------- LAYOUT PANTALLAS PEQUEÑAS ----------
                          return Column(
                            children: [
                              if (ctrl.loading) const LinearProgressIndicator(),
                              const SizedBox(height: 8),

                              // Jugadores arriba
                              SizedBox(
                                height: 140,
                                child: playersList,
                              ),

                              const SizedBox(height: 8),

                              // Tablero ocupa casi todo
                              Expanded(child: boardOverlay),

                              const SizedBox(height: 8),

                              // Botones + emotes abajo
                              actionsColumn,
                            ],
                          );
                        }),

                        // -------------------------
                        // OVERLAY DE EMOTES (MOSTRAR LO QUE LLEGA DEL HUB)
                        // -------------------------
                        if (ctrl.emotes.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: ctrl.emotes.map((e) {
                                final emoji = _emoteEmoji(e.emoteCode);
                                final from = e.fromUsername.isNotEmpty
                                    ? e.fromUsername
                                    : "Jugador";
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        from,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // -------------------------
                        // OVERLAY DEL DADO (DISEÑO BONITO + TILT)
                        // -------------------------
                        if (_showDice && _diceNumber != null)
                          Positioned.fill(
                            child: Center(
                              child: ScaleTransition(
                                scale: _diceScale,
                                child: Container(
                                  padding: const EdgeInsets.all(26),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.6),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: const Color(0xFF0DBA99)
                                          .withOpacity(0.9),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Has sacado",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Transform.rotate(
                                        angle: _diceTilt,
                                        child: _buildPrettyDice(_diceNumber!),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "$_diceNumber",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // -------------------------
                        // OVERLAY ESPECIAL (MATÓN / PROFESOR)
                        // -------------------------
                        if (_showSpecialOverlay && _specialMessage != null)
                          Positioned.fill(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.black87.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _specialMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // FULL SCREEN BOARD
  // -------------------------------------------------------------
  void _openFullScreenBoard(GameController ctrl) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tablero (pantalla completa)")),
        body: SafeArea(
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(40),
              minScale: 0.8,
              maxScale: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GameBoardWidget(
                  players: ctrl.game!.players,
                  snakes: ctrl.game!.snakes,
                  ladders: ctrl.game!.ladders,
                ),
              ),
            ),
          ),
        ),
      );
    }));
  }

  @override
  void dispose() {
    final ctrl = Provider.of<GameController>(context, listen: false);
    try {
      ctrl.removeListener(_onControllerChanged);
      ctrl.removeListener(_maybeStartAggressiveReload);
      ctrl.stopPollingGame();
    } catch (_) {}
    _diceController.dispose();
    _aggressiveReloadTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------
  // LISTENER DEL CONTROLLER — RENDICIÓN + EVENTOS ESPECIALES
  // -------------------------------------------------------------
  void _onControllerChanged() {
    final ctrl = Provider.of<GameController>(context, listen: false);
    final game = ctrl.game;

    // --- Detectar rendición por diferencia en la lista de jugadores ---
    if (game != null) {
      final currentIds = game.players
          .map((p) => p.id?.toString())
          .whereType<String>()
          .toList();

      if (_lastPlayerIds.isNotEmpty &&
          currentIds.length < _lastPlayerIds.length) {
        // Alguien salió
        final removed = _lastPlayerIds
            .where((id) => !currentIds.contains(id))
            .toList();
        if (removed.isNotEmpty) {
          final removedId = removed.first;
          final name = _lastPlayerNames[removedId] ?? "Un jugador";

          final auth = Provider.of<AuthController>(context, listen: false);
          final String? myId = auth.userId;

          // Solo se muestra a los otros jugadores
          if (myId == null || removedId != myId) {
            final phrases = [
              "$name tiró la toalla 🎓",
              "$name decidió probar el año sabático 🧳",
              "$name abandonó la materia a mitad de semestre 😵‍💫",
            ];
            final msg = phrases[Random().nextInt(phrases.length)];
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }

      // Actualizar snapshot de jugadores
      _lastPlayerIds = currentIds;
      _lastPlayerNames = {
        for (final p in game.players)
          if (p.id != null) p.id!.toString(): p.username,
      };

      // --- Mensaje de victoria / partida finalizada ---
      if (game.status != null) {
        final s = game.status!.toLowerCase();
        if (_lastGameStatus != s) {
          _lastGameStatus = s;
          if (s.contains('final') ||
              s.contains('finish') ||
              s.contains('gan')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("La partida ha terminado 🎉"),
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }
    } else {
      _lastPlayerIds = [];
      _lastPlayerNames = {};
    }

    // --- Evento especial Matón (cuando llegue en lastMoveResult) ---
    final mr = ctrl.lastMoveResult;
    if (mr == null) return;

    try {
      if (mr.specialEvent == "Matón" && !_showSpecialOverlay) {
        final auth = Provider.of<AuthController>(context, listen: false);
        final myUserId = auth.userId;
        final isMyMove =
            (ctrl.lastMovePlayerId?.toString() == myUserId);

        String message = "Un jugador ha sido ayudado por un matón!";
        if (ctrl.game != null && ctrl.lastMovePlayerId != null) {
          try {
            final player = ctrl.game!.players.firstWhere(
              (p) => p.id?.toString() == ctrl.lastMovePlayerId.toString(),
            );
            if (isMyMove) {
              message =
                  "Te han ayudado, subes hasta la casilla ${mr.finalPosition}";
            } else {
              message = "${player.username} ha sido ayudado por un matón!";
            }
          } catch (_) {}
        }

        setState(() {
          _specialMessage = message;
          _showSpecialOverlay = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showSpecialOverlay = false);
          }
        });
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // LÓGICA DEL BOTÓN "TIRAR DADO" + ANIMACIÓN
  // -------------------------------------------------------------
  Future<void> _handleRoll(GameController ctrl) async {
    if (_diceRolling || _showDice) return;

    _diceRolling = true;
    final random = Random();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      setState(() {
        _showDice = true;
        _diceNumber = random.nextInt(6) + 1;
        _diceTilt = 0.0;
      });
    }

    // 1) Animación local de números random (sin tocar backend todavía)
    const spinTotalMs = 2000; // un poco más largo
    const intervalMs = 80;
    final iterations = spinTotalMs ~/ intervalMs;

    for (int i = 0; i < iterations; i++) {
      await Future.delayed(const Duration(milliseconds: intervalMs));
      if (!mounted) return;
      setState(() {
        _diceNumber = random.nextInt(6) + 1;
        _diceTilt = (random.nextDouble() - 0.5) * 0.5; // tilt leve
      });
    }

    if (!mounted) {
      _diceRolling = false;
      return;
    }

    setState(() {
      _diceTilt = 0.0;
    });

    // 2) AHORA llamamos al backend (ctrl.roll)
    final ok = await ctrl.roll();

    // 3) Obtenemos el número real del backend (si existe)
    int finalNumber = _diceNumber ?? 1;
    try {
      final mr = ctrl.lastMoveResult;
      if (mr != null) {
        final diceVal = (mr.dice ?? mr.diceValue ?? 0);
        if (diceVal > 0) {
          finalNumber = diceVal;
        }
      }
    } catch (_) {
      // si falla, dejamos el random actual
    }

    if (!mounted) {
      _diceRolling = false;
      return;
    }

    setState(() => _diceNumber = finalNumber);

    // 4) Animación de "pop" final con el número verdadero
    _diceController.reset();
    await _diceController.forward();
    await Future.delayed(const Duration(milliseconds: 260));
    await _diceController.reverse();

    // 5) Lo dejamos un ratito visible
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      _diceRolling = false;
      return;
    }

    // 6) Ocultamos dado
    setState(() => _showDice = false);

    // 7) Mensaje como antes
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ok ? "Tirada realizada" : "No se pudo realizar la tirada"),
        ),
      );
    }

    _diceRolling = false;
  }

  // ------------------ DADO BONITO (PIPS 3x3) ------------------
  Widget _buildPrettyDice(int value) {
    final safeValue = value.clamp(1, 6);

    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            Colors.white,
            Color(0xFFF3FFF9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0xFF0DBA99).withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 1.2,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF0DBA99),
          width: 2.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _buildDicePips(safeValue),
      ),
    );
  }

  Widget _buildDicePips(int value) {
    final safeValue = value.clamp(1, 6);
    final Set<int> active = <int>{};

    switch (safeValue) {
      case 1:
        active.add(4);
        break;
      case 2:
        active
          ..add(0)
          ..add(8);
        break;
      case 3:
        active
          ..add(0)
          ..add(4)
          ..add(8);
        break;
      case 4:
        active..addAll([0, 2, 6, 8]);
        break;
      case 5:
        active..addAll([0, 2, 4, 6, 8]);
        break;
      default: // 6
        active..addAll([0, 2, 3, 5, 6, 8]);
        break;
    }

    return GridView.builder(
      itemCount: 9,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemBuilder: (_, index) {
        final show = active.contains(index);
        return Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: show ? 1 : 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF163430),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // EMOTES HELPERS
  // -------------------------------------------------------------
  String _emoteEmoji(int code) {
    switch (code) {
      case 0:
        return "🙂";
      case 1:
        return "😂";
      case 2:
        return "😡";
      case 3:
        return "😭";
      case 4:
        return "🤓";
      default:
        return "😶";
    }
  }

  Widget _buildEmoteButton(GameController ctrl, int emoteCode) {
    final emoji = _emoteEmoji(emoteCode);
    // sólo deshabilitamos si no hay partida o está cargando
    final disabled = (ctrl.game == null || ctrl.loading);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: disabled
          ? null
          : () async {
              await ctrl.sendEmote(emoteCode);
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 0.7,
            ),
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // DIÁLOGO DE PREGUNTA DEL PROFESOR
  // -------------------------------------------------------------
  Future<void> _showProfesorQuestionDialog(ProfesorQuestionDto question) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Pregunta del profesor"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Profesor ${question.profesor}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(question.question),
              const SizedBox(height: 16),
              ...question.options.asMap().entries.map((entry) {
                final index = entry.key;
                final opt = entry.value;
                final letters = ['A', 'B', 'C', 'D'];
                final letter =
                    index < letters.length ? letters[index] : '${index + 1}';
                final label =
                    opt.trim().isEmpty ? "Opción $letter" : "$letter) $opt";

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();

                      final letterToSend =
                          question.getLetterForValue(opt) ?? letter;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Enviando respuesta...'),
                            ],
                          ),
                          duration: Duration(seconds: 10),
                        ),
                      );

                      final result = await _submitProfesorAnswer(
                          question.questionId, letterToSend, context);

                      if (mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        await Future.delayed(
                            const Duration(milliseconds: 300));
                        if (mounted &&
                            result != null &&
                            result['message'] != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] as String),
                              backgroundColor: result['isCorrect'] == true
                                  ? Colors.green
                                  : Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(label),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // ENVÍO DE RESPUESTA DEL PROFESOR
  // -------------------------------------------------------------
  Future<Map<String, dynamic>?> _submitProfesorAnswer(
      String questionId, String answer, BuildContext ctx) async {
    final ctrl = Provider.of<GameController>(context, listen: false);

    try {
      var res = await ctrl
          .answerProfesor(questionId, answer)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return null;

      if (res == null || res['success'] != true) {
        await _showErrorDialog(
          ctx,
          "Error al responder",
          "No se pudo enviar la respuesta. Intenta nuevamente.",
        );
        return null;
      }

      final moveResult = res['moveResult'];
      if (moveResult != null) {
        final message = moveResult.message ?? 'Respuesta procesada';
        final fromPos = moveResult.fromPosition ?? 0;
        final finalPos = moveResult.finalPosition ?? 0;

        final messageText = message.toLowerCase();
        final isCorrect = messageText.contains('correcto') ||
            messageText.contains('mantienes') ||
            (fromPos == finalPos && !messageText.contains('incorrecto'));

        return {
          'message': message,
          'isCorrect': isCorrect,
          'fromPosition': fromPos,
          'finalPosition': finalPos,
        };
      }

      return {'message': 'Respuesta enviada', 'isCorrect': true};
    } catch (e) {
      developer.log(
        "Error al enviar respuesta del profesor: $e",
        name: "GameBoardPage",
      );
      if (!mounted) return null;
      await _showErrorDialog(
        ctx,
        "Error al responder",
        "Ocurrió un problema al enviar la respuesta. Intenta nuevamente.",
      );
      return null;
    }
  }

  // -------------------------------------------------------------
  // DIALOG ERROR
  // -------------------------------------------------------------
  Future<void> _showErrorDialog(
      BuildContext ctx, String title, String message) async {
    try {
      await showDialog<void>(
        context: ctx,
        builder: (_) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  Navigator.of(ctx).pop();
                },
                child: const Text("Copiar"),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cerrar"),
              ),
            ],
          );
        },
      );
    } catch (_) {}
  }

  // ------------------ FONDO TEMÁTICO ------------------
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
          top: 80,
          left: 40,
          child: _softIcon(Icons.casino_rounded, 70),
        ),
        Positioned(
          top: 160,
          right: 50,
          child: _softIcon(Icons.stairs_rounded, 60),
        ),
        Positioned(
          bottom: 80,
          left: 80,
          child: _softIcon(Icons.school_rounded, 70),
        ),
        Positioned(
          bottom: 40,
          right: 80,
          child: _softIcon(Icons.person_off_rounded, 60),
        ),
      ],
    );
  }

  Widget _softIcon(IconData icon, double size) {
    return Icon(
      icon,
      size: size,
      color: Colors.white.withOpacity(0.07),
    );
  }

  // ------------------ BOTÓN ESTILO JUEGO ------------------
  Widget _buildGameButton({
    required String text,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    bool loading = false,
    Color? color,
  }) {
    final Color bg = color ?? const Color(0xFF0DBA99);

    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: enabled && !loading ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  bg,
                  Color.lerp(bg, Colors.black, 0.2)!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: bg.withOpacity(0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

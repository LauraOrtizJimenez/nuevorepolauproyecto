// -------------------------------------------------------------
// GameBoardPage.dart  (VERSIÓN LIMPIA PARA DEMO + TEMÁTICA JUEGO)
// -------------------------------------------------------------

import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/state/auth_controller.dart';

import '../state/game_controller.dart';
import 'game_board_widget.dart';
import '../../auth/presentation/logout_button.dart';

class GameBoardPage extends StatefulWidget {
  final String gameId;
  const GameBoardPage({super.key, required this.gameId});

  @override
  State<GameBoardPage> createState() => _GameBoardPageState();
}

class _GameBoardPageState extends State<GameBoardPage>
    with TickerProviderStateMixin {
  static const Color _baseGreen = Color(0xFF065A4B);

  late final AnimationController _diceController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _diceScale =
      CurvedAnimation(parent: _diceController, curve: Curves.elasticOut);

  bool _showDice = false;
  int? _diceNumber;
  bool _diceRolling = false;

  // Overlay (profesor/matón)
  bool _showSpecialOverlay = false;
  String? _specialMessage;

  // Aggressive reload
  bool _waitingForPlayers = false;
  Timer? _aggressiveReloadTimer;
  int _aggressiveReloadAttempts = 0;

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

    // Si llega pregunta → mostrar dialogo
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ctrl.currentQuestion != null) {
        final q = ctrl.currentQuestion!;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              title: const Text("Pregunta del profesor"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(q.question),
                  const SizedBox(height: 12),
                  ...q.options.map(
                    (opt) {
                      final label =
                          opt.trim().isEmpty ? "Opción" : opt; // sin "<empty>"
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ElevatedButton(
                          onPressed: ctrl.answering
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();

                                  await _submitProfesorAnswer(
                                      q.questionId, opt, ctx);
                                  ctrl.clearCurrentQuestion();
                                  ctrl.setAnswering(false);
                                },
                          child: ctrl.answering
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(label),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
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
                                          animatePlayerId:
                                              ctrl.lastMovePlayerId,
                                          animateSteps:
                                              ctrl.lastMoveResult?.diceValue,
                                          onAnimationComplete: () {
                                            if (ctrl
                                                .hasPendingSimulatedGame()) {
                                              ctrl.applyPendingSimulatedGame();
                                              ctrl.lastMoveSimulated = false;
                                              ctrl.lastMovePlayerId = null;
                                              ctrl.lastMoveResult = null;
                                            } else if (ctrl.game != null) {
                                              Future.microtask(() =>
                                                  ctrl.loadGame(
                                                      ctrl.game!.id));
                                              ctrl.lastMovePlayerId = null;
                                              ctrl.lastMoveResult = null;
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

                          Widget actionsColumn = Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
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
                                    onTap: () async {
                                      final ok = await ctrl.roll();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? "Tirada realizada"
                                                : "No se pudo realizar la tirada",
                                          ),
                                        ),
                                      );
                                    },
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
                                        Navigator.pushReplacementNamed(
                                            context, "/lobby");
                                      } else {
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
                                SizedBox(width: 190, child: actionsColumn),
                              ],
                            );
                          }

                          // Layout para pantallas pequeñas
                          return Column(
                            children: [
                              if (ctrl.loading) const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                              Expanded(child: boardOverlay),
                              const SizedBox(height: 8),
                              SizedBox(height: 150, child: playersList),
                              const SizedBox(height: 8),
                              actionsColumn,
                            ],
                          );
                        }),

                        // -------------------------
                        // OVERLAY DEL DADO
                        // -------------------------
                        if (_showDice && _diceNumber != null)
                          Positioned.fill(
                            child: Center(
                              child: ScaleTransition(
                                scale: _diceScale,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.black87.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withOpacity(0.5),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Has sacado",
                                        style:
                                            TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),
                                      CircleAvatar(
                                        radius: 38,
                                        backgroundColor:
                                            const Color(0xFF0DBA99),
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "$_diceNumber",
                                              style: const TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
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
                                    const SizedBox(height: 12),
                                    Builder(
                                      builder: (ctx) {
                                        final c =
                                            Provider.of<GameController>(ctx);
                                        if (c.currentQuestion != null) {
                                          final q = c.currentQuestion!;
                                          return Column(
                                            children: [
                                              Text(
                                                q.question,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              ...q.options.map(
                                                (opt) {
                                                  final label =
                                                      opt.trim().isEmpty
                                                          ? "Opción"
                                                          : opt;
                                                  return Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4),
                                                    child: ElevatedButton(
                                                      onPressed: c.answering
                                                          ? null
                                                          : () async {
                                                              await _submitProfesorAnswer(
                                                                  q.questionId,
                                                                  opt,
                                                                  ctx);
                                                              c.clearCurrentQuestion();
                                                              c.setAnswering(
                                                                  false);
                                                            },
                                                      child: Text(label),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        }
                                        return const SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 3),
                                        );
                                      },
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
  // ON CONTROLLER CHANGED — ANIMACIÓN DE DADO
  // -------------------------------------------------------------
  void _onControllerChanged() async {
    final ctrl = Provider.of<GameController>(context, listen: false);
    final mr = ctrl.lastMoveResult;
    if (mr == null) return;

    int applied = (mr.dice >= 1 && mr.dice <= 6) ? mr.dice : mr.dice;
    if (applied <= 0) applied = 1;
    if (applied > 6) applied = ((applied % 6) == 0) ? 6 : (applied % 6);

    _diceNumber = 1;

    setState(() => _showDice = true);

    await _playDiceRollAnimation(applied);

    if (!mounted) return;

    setState(() => _showDice = false);

    // Overlay Matón
    try {
      final newPos = mr.newPosition;
      bool hitMaton = false;

      if (ctrl.game != null) {
        hitMaton = ctrl.game!.snakes.any((s) => s.headPosition == newPos);
      }

      if (hitMaton) {
        _specialMessage =
            "¡Te comió un Matón! Retrocedes a ${mr.newPosition}";
        setState(() => _showSpecialOverlay = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showSpecialOverlay = false);
        });
      }
    } catch (_) {}

    ctrl.lastMoveResult = null;

    if (ctrl.hasPendingSimulatedGame()) {
      ctrl.applyPendingSimulatedGame();
      ctrl.lastMoveSimulated = false;
    } else if (ctrl.game != null) {
      Future.microtask(() => ctrl.loadGame(ctrl.game!.id));
    }
  }

  // -------------------------------------------------------------
  // ANIMACIÓN REAL DEL DADO
  // -------------------------------------------------------------
  Future<void> _playDiceRollAnimation(int finalNumber) async {
    if (_diceRolling) return;
    _diceRolling = true;

    try {
      const List<int> phases = [60, 60, 60, 60, 80, 100, 140, 200];

      if (_diceNumber == null) _diceNumber = 1;

      for (final d in phases) {
        await Future.delayed(Duration(milliseconds: d));
        if (!mounted) return;
        setState(() => _diceNumber = (_diceNumber! % 6) + 1);
      }

      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() => _diceNumber = finalNumber);

      _diceController.reset();
      await _diceController.forward();
      await Future.delayed(const Duration(milliseconds: 260));
      await _diceController.reverse();
    } finally {
      _diceRolling = false;
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

  // -------------------------------------------------------------
  // ENVÍO DE RESPUESTA DEL PROFESOR
  // -------------------------------------------------------------
  Future<void> _submitProfesorAnswer(
      String questionId, String answer, BuildContext ctx) async {
    final ctrl = Provider.of<GameController>(context, listen: false);

    try {
      var res;

      try {
        res = await ctrl
            .answerProfesor(questionId, answer)
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        try {
          res = await ctrl
              .answerProfesor(questionId, answer)
              .timeout(const Duration(seconds: 15));
        } on TimeoutException {
          if (!mounted) return;
          await _showErrorDialog(
            ctx,
            "Tiempo de espera agotado",
            "La respuesta tardó demasiado en procesarse. Intenta nuevamente.",
          );
          return;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            res != null
                ? "Respuesta enviada"
                : "No se pudo enviar la respuesta",
          ),
        ),
      );
    } catch (e) {
      developer.log(
        "Error al enviar respuesta del profesor: $e",
        name: "GameBoardPage",
      );
      if (!mounted) return;
      await _showErrorDialog(
        ctx,
        "Error al responder",
        "Ocurrió un problema al enviar la respuesta. Intenta nuevamente.",
      );
    }
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

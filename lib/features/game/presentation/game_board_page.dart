// -------------------------------------------------------------
// GameBoardPage.dart  (VERSIÓN LIMPIA + EMOTES)
// -------------------------------------------------------------

import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../auth/state/auth_controller.dart';

import '../state/game_controller.dart';
import 'game_board_widget.dart';
import '../../auth/presentation/logout_button.dart';
import '../../../core/models/profesor_question_dto.dart';
import '../../../core/models/game_state_dto_clean.dart';
import '../../../core/services/user_service.dart';

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

  // Confetti controller para la victoria
  late final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 5));

  bool _showDice = false;
  int? _diceNumber;
  bool _diceRolling = false;
  double _diceTilt = 0.0;
  bool _allowBoardAnimation = true; // Controla si se puede animar el tablero
  GameStateDto? _frozenGameState; // Estado congelado del juego mientras el dado está visible
  String? _rollingPlayerId; // ID del jugador que está tirando (para congelar solo su vista)

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
        
        // Esperar a que termine TODO:
        // 1. Animación del dado (2000ms random + tiempo backend + 700ms visible = ~3000ms)
        // 2. Animación del movimiento en el tablero (250ms por paso)
        final diceValue = ctrl.lastMoveResult?.diceValue ?? 0;
        if (diceValue > 0) {
          // Tiempo del dado: ~3200ms (animación + mostrar número)
          final diceTime = 3200;
          // Tiempo de animación del tablero: 250ms por paso + extra
          final boardAnimationTime = (diceValue * 250) + 300;
          final totalTime = diceTime + boardAnimationTime;
          await Future.delayed(Duration(milliseconds: totalTime));
        }
        
        await _showProfesorQuestionDialog(question);
        _profesorDialogShowing = false;
      }
    });

    // Solo usar estado congelado si SOY YO quien está tirando el dado
    final myPlayerId = ctrl.currentUserId;
    final shouldFreeze = _frozenGameState != null && _rollingPlayerId == myPlayerId;
    final game = shouldFreeze ? _frozenGameState : ctrl.game;
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
            Text(
              "Partida",
              style: GoogleFonts.pressStart2p(fontSize: 10),
            ),
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
                          Expanded(
                            child: Text(
                              "Problemas de conexión. Intentando mantener la partida activa.",
                              style: GoogleFonts.pressStart2p(fontSize: 7, height: 1.5),
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
                            label: Text(
                              "Reintentar",
                              style: GoogleFonts.pressStart2p(fontSize: 7, height: 1.5),
                            ),
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
                              style: GoogleFonts.pressStart2p(
                                fontSize: 10,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              gameStatus.isNotEmpty
                                  ? "Estado: $gameStatus"
                                  : "Esperando actualización...",
                              style: GoogleFonts.pressStart2p(
                                fontSize: 7,
                                color: Colors.white70,
                                height: 1.5,
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
                              style: GoogleFonts.pressStart2p(
                                fontSize: 8,
                                color: Colors.white,
                                height: 1.5,
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
                            return Center(
                              child: Text(
                                "No hay partida cargada",
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 10,
                                  color: Colors.white,
                                  height: 1.5,
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
                              padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: large
                                      ? constraints.maxWidth * 0.50
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
                                          // Animación del tablero (solo si se permite)
                                          animatePlayerId:
                                              _allowBoardAnimation && (ctrl.lastMoveResult?.diceValue ?? 0) > 0
                                                  ? ctrl.lastMovePlayerId
                                                  : null,
                                          animateSteps:
                                              _allowBoardAnimation && (ctrl.lastMoveResult?.diceValue ?? 0) > 0
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
                                      children: [
                                        const Icon(Icons.groups_rounded,
                                            color: Colors.white70, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Jugadores",
                                          style: GoogleFonts.pressStart2p(
                                            fontSize: 9,
                                            color: Colors.white,
                                            height: 1.5,
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
                                                style: GoogleFonts.pressStart2p(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  height: 1.5,
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
                                                style: GoogleFonts.pressStart2p(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  height: 1.5,
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
                              padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!ctrl.isMyTurn)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Text(
                                        "Turno de: ${ctrl.currentTurnUsername}",
                                        style: GoogleFonts.pressStart2p(
                                          color: Colors.white70,
                                          fontSize: 8,
                                          height: 1.5,
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
                                    label: Text(
                                      "Actualizar",
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 8,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(
                                    color: Colors.white.withOpacity(0.35),
                                    height: 18,
                                  ),
                                  const SizedBox(height: 4),
                                  // ---------- EMOTES UI ----------
                                  Text(
                                    "Reacciones",
                                    style: GoogleFonts.pressStart2p(
                                      color: Colors.white70,
                                      fontSize: 8,
                                      height: 1.5,
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
                                  const SizedBox(height: 8),
                                  Text(
                                    "GIFs",
                                    style: GoogleFonts.pressStart2p(
                                      color: Colors.white70,
                                      fontSize: 8,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildEmoteButton(ctrl, 7),
                                      _buildEmoteButton(ctrl, 8),
                                      _buildEmoteButton(ctrl, 9),
                                      _buildEmoteButton(ctrl, 10),
                                      _buildEmoteButton(ctrl, 11),
                                      // Agregar más botones GIF aquí: _buildEmoteButton(ctrl, 12), etc.
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
                            bottom: 50,
                            right: 365,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              verticalDirection: VerticalDirection.up,
                              children: ctrl.emotes.map((e) {
                                final isGif = _isGifEmote(e.emoteCode);
                                
                                if (isGif) {
                                  final gifUrl = _emoteGifUrl(e.emoteCode);
                                  if (gifUrl != null) {
                                    return Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      width: 80,
                                      height: 80,
                                      child: Image.network(
                                        gifUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Text('❌', style: TextStyle(fontSize: 48));
                                        },
                                      ),
                                    );
                                  }
                                }
                                
                                // Emoji Unicode normal
                                final emoji = _emoteEmoji(e.emoteCode);
                                return Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // -------------------------
                        // MENSAJES DE SURRENDER
                        // -------------------------
                        if (ctrl.surrenderEvents.isNotEmpty)
                          ...ctrl.surrenderEvents.map((event) {
                            final message = event['message'] ?? 'Un jugador se rindió';
                            return Positioned(
                              top: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE57373),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    message,
                                    style: GoogleFonts.pressStart2p(
                                      fontSize: 10,
                                      color: Colors.white,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),

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
                        // CONFETTI DE VICTORIA
                        // -------------------------
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConfettiWidget(
                            confettiController: _confettiController,
                            blastDirectionality: BlastDirectionality.explosive,
                            shouldLoop: false,
                            particleDrag: 0.03,
                            emissionFrequency: 0.01,
                            numberOfParticles: 50,
                            gravity: 0.2,
                            minBlastForce: 80,
                            maxBlastForce: 120,
                            colors: const [
                              Colors.green,
                              Colors.blue,
                              Colors.pink,
                              Colors.orange,
                              Colors.purple,
                              Colors.yellow,
                              Colors.red,
                              Colors.cyan,
                            ],
                          ),
                        ),

                        // -------------------------
                        // OVERLAY ESPECIAL (MATÓN / PROFESOR)
                        // -------------------------
                        if (_showSpecialOverlay && _specialMessage != null)
                          Positioned(
                            top: 80,
                            left: 0,
                            right: 0,
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
    _confettiController.dispose();
    _aggressiveReloadTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------
  // LISTENER DEL CONTROLLER — RENDICIÓN + EVENTOS ESPECIALES
  // -------------------------------------------------------------
  void _onControllerChanged() async {
    final ctrl = Provider.of<GameController>(context, listen: false);
    final game = ctrl.game;

    // --- Detectar rendición por diferencia en la lista de jugadores ---
    if (game != null) {
      final currentIds = game.players
          .map((p) => p.id.toString())
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
              "$name decidió tomar un año sabático 🧳",
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
        
        // VERIFICAR GANADOR POR RENDICIÓN (fuera del if anterior)
        // Si después de la rendición queda solo 1 jugador activo -> ese jugador gana
        final auth = Provider.of<AuthController>(context, listen: false);
        final String? myId = auth.userId;
        
        if (currentIds.length == 1 && myId != null && currentIds.contains(myId.toString())) {
          // Yo soy el único que queda, soy el ganador
          _confettiController.play();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 ¡Felicidades! Has ganado por rendición del oponente 🏆"),
                duration: Duration(seconds: 5),
                backgroundColor: Color(0xFF0DBA99),
              ),
            );
          }

          // Incrementar victorias
          try {
            await auth.incrementWins();
            final userService = UserService();
            await userService.incrementWins();
          } catch (e) {
            developer.log('Error incrementando victorias por rendición: $e', name: 'GameBoardPage');
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
        _rollingPlayerId = ctrl.currentUserId; // Guardar quién está tirando
        _allowBoardAnimation = false; // Bloquear animación del tablero
        _frozenGameState = ctrl.game; // CONGELAR el estado actual del juego SOLO PARA MÍ
      });
    }

    // 1) Animación local de números random (sin tocar backend todavía)
    const spinTotalMs = 2000;
    const intervalMs = 80;
    final iterations = spinTotalMs ~/ intervalMs;

    for (int i = 0; i < iterations; i++) {
      await Future.delayed(const Duration(milliseconds: intervalMs));
      if (!mounted) return;
      setState(() {
        _diceNumber = random.nextInt(6) + 1;
        _diceTilt = (random.nextDouble() - 0.5) * 0.5;
      });
    }

    if (!mounted) {
      _diceRolling = false;
      return;
    }

    setState(() {
      _diceTilt = 0.0;
    });

    // 2) Llamar al backend para obtener el número real del dado
    final ok = await ctrl.roll();

    // 3) Obtener el número real del backend
    int finalNumber = _diceNumber ?? 1;
    bool playerWon = false;
    try {
      final mr = ctrl.lastMoveResult;
      if (mr != null) {
        final diceVal = (mr.dice ?? mr.diceValue ?? 0);
        if (diceVal > 0) {
          finalNumber = diceVal;
        }
        if (mr.isWinner) {
          playerWon = true;
        }
      }
    } catch (_) {
      // si falla, dejamos el random actual
    }

    if (!mounted) {
      _diceRolling = false;
      return;
    }

    // 4) Mostrar el número REAL del backend
    setState(() => _diceNumber = finalNumber);

    // 5) Animación de "pop" con el número CORRECTO
    _diceController.reset();
    await _diceController.forward();
    await Future.delayed(const Duration(milliseconds: 260));
    await _diceController.reverse();

    // 6) Lo dejamos visible un ratito
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      _diceRolling = false;
      return;
    }

    // 7) Ocultamos dado y DESCONGELAMOS el estado
    setState(() {
      _showDice = false;
      _frozenGameState = null; // DESCONGELAR - ahora el widget verá el estado actualizado
      _rollingPlayerId = null; // Limpiar quién estaba tirando
      _allowBoardAnimation = true; // Permitir animación
    });
    
    // Pequeño delay para que se dispare la animación
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) {
      _diceRolling = false;
      return;
    }

    // 7) Si el jugador ganó, incrementar victorias
    if (playerWon) {
      final auth = Provider.of<AuthController>(context, listen: false);
      try {
        await auth.incrementWins();
        final userService = UserService();
        await userService.incrementWins();
      } catch (e) {
        developer.log('Error incrementando victorias: $e', name: 'GameBoardPage');
      }
      
      // Disparar confeti
      _confettiController.play();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 ¡Felicidades! Has ganado la partida 🏆"),
            duration: Duration(seconds: 5),
            backgroundColor: Color(0xFF0DBA99),
          ),
        );
      }
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
        ],
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
        return "🙀";
      case 1:
        return "😿";
      case 2:
        return "😹";
      case 3:
        return "😾";
      case 4:
        return "😸";
      default:
        return "😶";
    }
  }

  // Detectar si el código es un GIF (códigos 7+)
  bool _isGifEmote(int code) {
    return code >= 7;
  }

  // Obtener URL del GIF según el código
  String? _emoteGifUrl(int code) {
    switch (code) {
      case 7:
        return "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExYWNoMGM0ZWplbHp6NHJ2NzZ0dmZqNHhpeHEwcjhkdGFjZ29uemNpdyZlcD12MV9zdGlja2Vyc19zZWFyY2gmY3Q9cw/zy6ts0cxT5l9PydjzM/giphy.gif";
      case 8:
        return "https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExMTR6emEyY3BtZndnZDBrNzFycjRkcWpnbW9xMWZqeWRxd2JhMnNqMSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/9SolVg03SeKJMl18en/giphy.gif";
      case 9:
        return "https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExZmJmYnUyaGgzYzV2MmE4bDl4Z3V2NHdyOXd6cXFobnRuNGU1MHpibyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/OtctZaDj6oUdpaHDra/giphy.gif";
      case 10:
        return "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3g4eW9nMXR6MWsxMTE1d3JleDR0anVkMmxkajFsNnJwMjFkcjJweCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/WobKKxW5i4M6hS8PxD/giphy.gif";
      case 11:
        return "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExODZ1NHFqdDgzNnZkc3Fta3gwOHNhbW92MDh0MW10eG5qZ2k1M2V1eSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/gQgCdTVivhNAzPPmGb/giphy.gif";
      // Agregar más GIFs aquí con códigos 12, 13, etc.
      default:
        return null;
    }
  }

  Widget _buildEmoteButton(GameController ctrl, int emoteCode) {
    final isGif = _isGifEmote(emoteCode);
    final disabled = (ctrl.game == null || ctrl.loading);

    Widget buttonChild;
    if (isGif) {
      final gifUrl = _emoteGifUrl(emoteCode);
      buttonChild = gifUrl != null
          ? SizedBox(
              width: 32,
              height: 32,
              child: Image.network(
                gifUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text('❌', style: TextStyle(fontSize: 18));
                },
              ),
            )
          : const Text('❌', style: TextStyle(fontSize: 18));
    } else {
      final emoji = _emoteEmoji(emoteCode);
      buttonChild = Text(
        emoji,
        style: const TextStyle(fontSize: 22),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.15),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        elevation: 2,
      ),
      onPressed: disabled
          ? null
          : () async {
              print('🔥 Botón emote presionado: $emoteCode');
              await ctrl.sendEmote(emoteCode);
              print('✅ Emote procesado');
            },
      child: buttonChild,
    );
  }

  // -------------------------------------------------------------
  // DIÁLOGO DE PREGUNTA DEL PROFESOR
  // -------------------------------------------------------------
  Future<void> _showProfesorQuestionDialog(ProfesorQuestionDto question) async {
    bool answered = false;
    
    // Timer de 12 segundos
    final timer = Timer(const Duration(seconds: 12), () async {
      if (!answered && mounted) {
        answered = true;
        // Cerrar el diálogo automáticamente
        Navigator.of(context, rootNavigator: true).pop();
        
        // Enviar respuesta incorrecta (respuesta vacía o X)
        await _submitProfesorAnswer(question.questionId, 'X', context);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏰ Tiempo agotado - Retrocedes'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Obtener imagen del profesor
        String getProfesorImage(String nombre) {
          final nombreLower = nombre.toLowerCase().trim();
          return 'assets/profesores/$nombreLower.png';
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Imagen del profesor - Más cerca de la pizarra
              ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    getProfesorImage(question.profesor),
                    width: 280,
                    height: 350,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Si no encuentra la imagen, muestra un placeholder
                      return Container(
                        width: 280,
                        height: 350,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 120,
                          color: Colors.white54,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(width: 10), // Pequeño espacio entre profesor y pizarra
              // Pizarra
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  // Marco de madera
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8B4513),
                      Color(0xFF654321),
                      Color(0xFF8B4513),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    // Fondo verde de pizarra
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1B5E44),
                        Color(0xFF0F4A36),
                        Color(0xFF1B5E44),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Título con subrayado de tiza
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pregunta del Profesor",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          height: 2,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 12, end: 0),
                      duration: const Duration(seconds: 12),
                      builder: (context, value, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: value <= 4 
                                ? Colors.red.withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: value <= 4 ? Colors.red : Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '⏱️ ${value}s',
                            style: TextStyle(
                              color: value <= 4 
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              shadows: [
                                Shadow(
                                  color: value <= 4 ? Colors.red : Colors.white.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Nombre del profesor con estilo tiza
                Text(
                  'Profesor ${question.profesor}',
                      style: TextStyle(
                        color: const Color(0xFFFFF8DC), // Color tiza amarillo
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFFF8DC).withOpacity(0.3),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 20),
                // Pregunta con estilo escrito en tiza
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.question,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 17,
                      height: 1.5,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                      // Opciones
                      ...question.options.asMap().entries.map((entry) {
                final index = entry.key;
                final opt = entry.value;
                final letters = ['A', 'B', 'C', 'D'];
                final letter =
                    index < letters.length ? letters[index] : '${index + 1}';
                final label =
                    opt.trim().isEmpty ? "Opción $letter" : "$letter) $opt";

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (answered) return; // Ya se respondió
                        answered = true;
                        timer.cancel(); // Cancelar el timer
                        
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Círculo con letra estilo tiza
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 2.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Texto de la opción con efecto tiza
                            Expanded(
                              child: Text(
                                opt,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 16,
                                  letterSpacing: 0.3,
                                  height: 1.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.white.withOpacity(0.2),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                      );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            // Soporte inferior de madera
            Container(
              width: 620,
              height: 35,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF8B4513),
                    Color(0xFF654321),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Borrador
                  Container(
                    margin: const EdgeInsets.only(left: 40, top: 8),
                    width: 50,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8DC),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Tiza azul
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 8,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9BDC),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
                ],
              ),
            ],
          ),
        );
      },
    );
    
    // Asegurarse de cancelar el timer cuando el diálogo se cierra
    timer.cancel();
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
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/fondolobby.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.3),
                BlendMode.darken,
              ),
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
                          style: GoogleFonts.pressStart2p(
                            fontSize: 9,
                            color: Colors.white,
                            height: 1.5,
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
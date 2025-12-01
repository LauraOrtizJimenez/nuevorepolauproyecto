import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/models/player_state_dto.dart';
import '../../../core/models/snake_dto.dart';
import '../../../core/models/ladder_dto.dart';

class GameBoardWidget extends StatefulWidget {
  final List<PlayerStateDto> players;
  final List<SnakeDto> snakes;
  final List<LadderDto> ladders;
  final int size;

  final String? animatePlayerId;
  final int? animateSteps;
  final VoidCallback? onAnimationComplete;

  const GameBoardWidget({
    super.key,
    required this.players,
    this.snakes = const [],
    this.ladders = const [],
    this.size = 10,
    this.animatePlayerId,
    this.onAnimationComplete,
    this.animateSteps,
  });

  @override
  State<GameBoardWidget> createState() => _GameBoardWidgetState();
}

class _GameBoardWidgetState extends State<GameBoardWidget> {
  bool _isAnimating = false;
  int _animatedTileIndex = 0;
  int _animStartPos = 0;
  int _animPlayerIndex = -1;
  Timer? _animTimer;

  @override
  void didUpdateWidget(covariant GameBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animatePlayerId != null &&
        widget.animateSteps != null &&
        !_isAnimating) {
      final idx =
          widget.players.indexWhere((p) => p.id == widget.animatePlayerId);
      if (idx < 0) return;

      _animPlayerIndex = idx;

      final playerFinalPos = widget.players[idx].position;
      final steps = max(1, widget.animateSteps!);

      int oldPosition = max(1, playerFinalPos - steps);

      try {
        if (oldWidget.players.isNotEmpty) {
          final oldPlayerIndex = oldWidget.players.indexWhere(
            (p) => p.id == widget.animatePlayerId,
          );
          if (oldPlayerIndex >= 0) {
            oldPosition = oldWidget.players[oldPlayerIndex].position;
          }
        }
      } catch (_) {}

      _animStartPos = oldPosition;
      _animatedTileIndex = _animStartPos;

      _isAnimating = true;
      int remaining = steps;

      const stepMs = 250;
      _animTimer?.cancel();
      _animTimer = Timer.periodic(
        const Duration(milliseconds: stepMs),
        (t) {
          if (!mounted) {
            t.cancel();
            return;
          }

          if (remaining <= 0) {
            t.cancel();
            _isAnimating = false;

            setState(() {
              _animatedTileIndex = 0;
            });

            widget.onAnimationComplete?.call();
            return;
          }

          remaining--;
          setState(() {
            _animatedTileIndex = min(
              _animatedTileIndex + 1,
              widget.size * widget.size,
            );
          });
        },
      );
    }
  }

  // 🎨 SKIN → COLOR
  Color _colorFromKey(String? key, int idxFallback) {
    const fallbackColors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
    ];

    if (key == null || key.isEmpty) {
      return fallbackColors[idxFallback % fallbackColors.length];
    }

    switch (key.toLowerCase()) {
      case 'red':
      case 'rojo':
        return Colors.red;
      case 'blue':
      case 'azul':
        return Colors.blue;
      case 'green':
      case 'verde':
        return Colors.green;
      case 'yellow':
      case 'amarillo':
        return Colors.yellow;
      case 'purple':
      case 'morado':
        return Colors.purple;
      case 'pink':
      case 'rosa':
        return Colors.pink;
      case 'orange':
      case 'naranja':
        return Colors.orange;
      default:
        return fallbackColors[idxFallback % fallbackColors.length];
    }
  }

  // 😎 SKIN → ICON
  String _iconCharFromKey(String? key, String username) {
    if (key == null || key.isEmpty) {
      return username.isNotEmpty ? username[0].toUpperCase() : '?';
    }

    switch (key.toLowerCase()) {
      case 'nerd':
        return '🤓';
      case 'angry':
        return '😡';
      case 'cool':
        return '😎';
      case 'classic':
        return username.isNotEmpty ? username[0].toUpperCase() : 'C';
      default:
        return username.isNotEmpty ? username[0].toUpperCase() : '?';
    }
  }

  Offset _tileCenter(int tileIndex, double tileSize, int size) {
    if (tileIndex <= 0) return Offset(-tileSize, -tileSize);
    final idx = tileIndex - 1;
    final rowFromBottom = idx ~/ size;
    final colInRow = idx % size;
    final row = (size - 1) - rowFromBottom;
    final isReversed = rowFromBottom % 2 == 1;
    final col = isReversed ? (size - 1 - colInRow) : colInRow;
    final left = col * tileSize;
    final top = row * tileSize;
    return Offset(left + tileSize / 2, top + tileSize / 2);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = min(constraints.maxWidth, constraints.maxHeight);

          const framePadding = 24.0;
          const borderPadding = 8.0;
          const totalPadding = (framePadding + borderPadding) * 2;

          final boardSize = size - totalPadding;
          final tileSize = boardSize / widget.size;

          return Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF4A2511),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2B48C),
                  border: Border.all(
                    color: const Color(0xFF8B6F47),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    width: boardSize,
                    height: boardSize,
                    child: Stack(
                      children: [
                        // GRID
                        Column(
                          children: List.generate(widget.size, (row) {
                            final isReversed =
                                (widget.size - 1 - row) % 2 == 1;
                            return Expanded(
                              child: Row(
                                children: List.generate(widget.size, (col) {
                                  final visualCol = isReversed
                                      ? (widget.size - 1 - col)
                                      : col;
                                  final tileIndex =
                                      (widget.size *
                                              (widget.size - 1 - row)) +
                                          visualCol +
                                          1;

                                  final bool isEven =
                                      (row + col) % 2 == 0;

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFF8B6F47)
                                            .withOpacity(0.3),
                                        width: 0.5,
                                      ),
                                      color: isEven
                                          ? const Color(0xFFF5DEB3)
                                          : const Color(0xFF8B4513),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 6,
                                          top: 6,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.7),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              '$tileIndex',
                                              style: TextStyle(
                                                fontSize: (tileSize * 0.15)
                                                    .clamp(9.0, 14.0),
                                                color:
                                                    const Color(0xFF4A2511),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Profesores y Matones
                                        Positioned(
                                          right: 6,
                                          bottom: 6,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              ...widget.snakes
                                                  .where((s) =>
                                                      s.headPosition ==
                                                      tileIndex)
                                                  .map(
                                                    (s) => Container(
                                                      width: tileSize * 0.25,
                                                      height: tileSize * 0.25,
                                                      decoration:
                                                          BoxDecoration(
                                                        color: Colors
                                                            .redAccent
                                                            .shade200,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: const Icon(
                                                        Icons.school,
                                                        size: 15,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),

                                              ...widget.ladders
                                                  .where((l) =>
                                                      l.bottomPosition ==
                                                      tileIndex)
                                                  .map(
                                                    (l) => Container(
                                                      width: tileSize * 0.25,
                                                      height: tileSize * 0.25,
                                                      decoration:
                                                          BoxDecoration(
                                                        color: Colors
                                                            .green.shade600,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: const Icon(
                                                        Icons.attach_money,
                                                        size: 15,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),

                        // TOKENS FIJOS
                        ...widget.players.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final player = entry.value;

                          final center = _tileCenter(
                            player.position,
                            tileSize,
                            widget.size,
                          );

                          final tokenSize =
                              (tileSize * 0.36).clamp(14.0, tileSize * 0.7);

                          double left = center.dx - tokenSize / 2;
                          double top = center.dy - tokenSize / 2;

                          left = left.clamp(0.0, boardSize - tokenSize);
                          top = top.clamp(0.0, boardSize - tokenSize);

                          if (_isAnimating && _animPlayerIndex == idx) {
                            return const SizedBox.shrink();
                          }

                          final color = _colorFromKey(
                              player.tokenColorKey, idx);
                          final label = _iconCharFromKey(
                              player.tokenIconKey, player.username);

                          return Positioned(
                            left: left,
                            top: top,
                            width: tokenSize,
                            height: tokenSize,
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              child: Tooltip(
                                message: player.username,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.95),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: (tokenSize * 0.45)
                                          .clamp(12.0, 18.0),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),

                        // TOKEN ANIMADO
                        if (_isAnimating &&
                            _animPlayerIndex >= 0 &&
                            _animatedTileIndex > 0)
                          Builder(builder: (ctx) {
                            if (_animPlayerIndex < 0 ||
                                _animPlayerIndex >=
                                    widget.players.length) {
                              return const SizedBox.shrink();
                            }

                            final overlayCenter = _tileCenter(
                              _animatedTileIndex,
                              tileSize,
                              widget.size,
                            );

                            final tokenSize =
                                (tileSize * 0.36).clamp(
                              14.0,
                              tileSize * 0.7,
                            );

                            double left =
                                overlayCenter.dx - tokenSize / 2;
                            double top =
                                overlayCenter.dy - tokenSize / 2;

                            left = left.clamp(0.0, boardSize - tokenSize);
                            top = top.clamp(0.0, boardSize - tokenSize);

                            final player =
                                widget.players[_animPlayerIndex];

                            final color = _colorFromKey(
                                player.tokenColorKey, _animPlayerIndex);
                            final label = _iconCharFromKey(
                                player.tokenIconKey, player.username);

                            return Positioned(
                              left: left,
                              top: top,
                              width: tokenSize,
                              height: tokenSize,
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                curve: Curves.easeInOut,
                                child: Tooltip(
                                  message: player.username,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.95),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 6,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize:
                                            (tokenSize * 0.45)
                                                .clamp(12.0, 18.0),
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 16),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Íconos con temática universidad / profesores / juego
  final _iconsMain = <IconData>[
    Icons.school_rounded,              // profe / graduación
    Icons.groups_rounded,              // estudiantes
    Icons.menu_book_rounded,           // libros
    Icons.science_rounded,             // laboratorio
    Icons.backpack_rounded,            // mochila
    Icons.casino_rounded,              // dado
    Icons.sentiment_very_dissatisfied, // matón
  ];

  final _iconsSmall = <IconData>[
    Icons.school_outlined,
    Icons.edit_note_rounded,
    Icons.quiz_rounded,
    Icons.calculate_rounded,
    Icons.emoji_events_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Stack(
      children: [
        // FONDO BASE
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF065A4B),
                Color(0xFF044339),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // CÍRCULOS GRANDES SUAVES (aprovechando esquinas y centro)
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final configs = [
              // top-left
              Offset(w * 0.15, h * 0.18),
              // middle-left
              Offset(w * 0.10, h * 0.55),
              // center
              Offset(w * 0.45, h * 0.40),
              // top-right
              Offset(w * 0.78, h * 0.20),
              // bottom-right
              Offset(w * 0.80, h * 0.70),
            ];

            return Stack(
              children: List.generate(configs.length, (i) {
                final t = _controller.value + i * 0.2;
                final dx = sin(t * 2 * pi) * (18 + 6 * i);
                final dy = cos(t * 2 * pi) * (18 + 6 * i);
                final baseSize = 180 + i * 50.0;

                return Positioned(
                  left: configs[i].dx + dx - baseSize / 2,
                  top: configs[i].dy + dy - baseSize / 2,
                  child: Container(
                    width: baseSize,
                    height: baseSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03 + i * 0.01),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),

        // ICONOS GRANDES FLOTÁNDO (puestos cerca de los círculos)
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final anchors = [
              Offset(w * 0.18, h * 0.12), // arriba izquierda
              Offset(w * 0.18, h * 0.33),
              Offset(w * 0.20, h * 0.62),

              Offset(w * 0.70, h * 0.18), // arriba derecha
              Offset(w * 0.72, h * 0.38),
              Offset(w * 0.78, h * 0.62),
            ];

            return Stack(
              children: List.generate(anchors.length, (i) {
                final t = _controller.value + i * 0.22;
                final dx = sin(t * pi) * 25;
                final dy = cos(t * pi) * 25;

                return Positioned(
                  left: anchors[i].dx + dx,
                  top: anchors[i].dy + dy,
                  child: Icon(
                    _iconsMain[i % _iconsMain.length],
                    size: 40,
                    color: Colors.white.withOpacity(
                      0.10 + _rnd.nextDouble() * 0.12,
                    ),
                  ),
                );
              }),
            );
          },
        ),

        // ICONOS PEQUEÑOS — dispersos por todo el mapa (grid suave)
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            // posiciones base en porcentaje (x, y)
            final positions = <Offset>[
              const Offset(0.08, 0.08),
              const Offset(0.30, 0.12),
              const Offset(0.55, 0.10),
              const Offset(0.88, 0.10),

              const Offset(0.09, 0.40),
              const Offset(0.32, 0.32),
              const Offset(0.60, 0.30),
              const Offset(0.88, 0.32),

              const Offset(0.10, 0.78),
              const Offset(0.35, 0.72),
              const Offset(0.65, 0.75),
              const Offset(0.90, 0.80),
            ];

            return Stack(
              children: List.generate(positions.length, (i) {
                final t = _controller.value + i * 0.18;
                final dx = sin(t * 2 * pi) * 10;
                final dy = cos(t * 2 * pi) * 10;

                final px = positions[i].dx * w;
                final py = positions[i].dy * h;

                return Positioned(
                  left: px + dx,
                  top: py + dy,
                  child: Icon(
                    _iconsSmall[i % _iconsSmall.length],
                    size: 22,
                    color: Colors.white.withOpacity(0.09),
                  ),
                );
              }),
            );
          },
        ),

        // “TIZAS” / BARRITAS QUE SE MUEVEN EN BORDES
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Stack(
              children: [
                // derecha
                ...List.generate(4, (i) {
                  final t = (_controller.value + i * 0.3);
                  final dx = sin(t * 2 * pi) * 22;

                  return Positioned(
                    bottom: 40.0 * (i + 1),
                    right: 28.0 + dx,
                    child: Container(
                      width: 70 + 10.0 * i,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  );
                }),
                // izquierda
                ...List.generate(3, (i) {
                  final t = (_controller.value + i * 0.35);
                  final dx = cos(t * 2 * pi) * 18;

                  return Positioned(
                    top: 60.0 * (i + 1),
                    left: 24.0 + dx,
                    child: Container(
                      width: 50 + 8.0 * i,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),

        // CONTENIDO (login / lo que envuelvas)
        widget.child,
      ],
    );
  }
}

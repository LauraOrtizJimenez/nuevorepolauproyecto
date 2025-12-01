import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class DiceWidget extends StatefulWidget {
  final double size;

  const DiceWidget({
    super.key,
    this.size = 72,
  });

  @override
  State<DiceWidget> createState() => DiceWidgetState();
}

class DiceWidgetState extends State<DiceWidget> {
  final _random = Random();
  int _currentFace = 1;
  bool _isRolling = false;

  bool get isRolling => _isRolling;
  int get value => _currentFace;

  /// Animación solo visual del dado:
  /// - Muestra números random unos milisegundos.
  /// - Termina en [finalValue].
  Future<void> playRoll(int finalValue) async {
    if (_isRolling) return;

    setState(() => _isRolling = true);

    const ticks = 14; // cuántas veces cambia
    const delay = Duration(milliseconds: 60);

    for (var i = 0; i < ticks; i++) {
      await Future.delayed(delay);
      if (!mounted) return;
      setState(() {
        _currentFace = _random.nextInt(6) + 1; // 1..6 random
      });
    }

    if (!mounted) return;
    setState(() {
      _currentFace = finalValue;
      _isRolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: FittedBox(
        child: Text(
          '$_currentFace',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
//
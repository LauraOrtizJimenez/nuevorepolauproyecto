import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  late AnimationController _bgController;
  late AnimationController _pulseController;

  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    // Animación de entrada del card
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Animación de fondo (rápida)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    // Pulso del botón principal
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    final rnd = Random();
    _particles = List.generate(70, (i) {
      return _Particle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        radius: 1.5 + rnd.nextDouble() * 3.5,
        speed: 0.4 + rnd.nextDouble() * 1.1,
        opacity: 0.05 + rnd.nextDouble() * 0.16,
      );
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    const Color baseGreen = Color(0xFF065A4B);

    return Scaffold(
      body: Stack(
        children: [
          _buildAnimatedBackground(),

          FadeTransition(
            opacity: _fadeIn,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth =
                        constraints.maxWidth < 520 ? constraints.maxWidth : 520;

                    return ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            width: 1.4,
                            color: const Color(0xFF0DBA99).withOpacity(0.6),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (ctx, cardConstraints) {
                            final bool isNarrow =
                                cardConstraints.maxWidth < 420;

                            final form = _buildFormSection(
                              context: ctx,
                              auth: auth,
                              baseGreen: baseGreen,
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 24,
                              ),
                              child: form,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // BACKGROUND ANIMADO
  // ────────────────────────────────────────────────

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Imagen de fondo
        Positioned.fill(
          child: Image.asset(
            'assets/fondo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback al fondo animado original si no encuentra la imagen
              return AnimatedBuilder(
                animation: _bgController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ParticlesPainter(
                      particles: _particles,
                      animation: _bgController,
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Overlay oscuro para que el texto se vea mejor
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _softIcon(IconData icon, double size) {
    return Icon(
      icon,
      size: size,
      color: Colors.white.withOpacity(0.1),
    );
  }

  // ────────────────────────────────────────────────
  // FORM
  // ────────────────────────────────────────────────
  Widget _buildFormSection({
    required BuildContext context,
    required AuthController auth,
    required Color baseGreen,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta arriba tipo "modo juego"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAFBF7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '🎲 Juego de tablero universitario',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF0A7D66),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),

        Text(
          'Profesores y Matones',
          style: GoogleFonts.pressStart2p(
            fontSize: 20,
            color: baseGreen,
            letterSpacing: 1,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Inicia sesión y reta a tus amigos.\n'
          'Responde bien, esquiva a los profes y gana monedas. 🪙',
          style: GoogleFonts.pressStart2p(
            fontSize: 9,
            color: Colors.black54,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 18),

        _buildInput(
          controller: _usernameCtrl,
          icon: Icons.person_outline,
          label: 'Usuario',
        ),
        const SizedBox(height: 10),

        _buildInput(
          controller: _passwordCtrl,
          icon: Icons.lock_outline,
          label: 'Contraseña',
          obscure: true,
        ),

        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '🎮 Tip: usa el mismo usuario que en el juego',
            style: GoogleFonts.pressStart2p(
              fontSize: 7,
              color: Colors.grey.shade600,
              height: 1.8,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Botón principal con pulso
        SizedBox(
          width: double.infinity,
          child: auth.loading
              ? const Center(child: CircularProgressIndicator())
              : AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = 1.0 + 0.03 * sin(_pulseController.value * 2 * pi);
                    return Transform.scale(
                      scale: pulse,
                      child: child,
                    );
                  },
                  child: _buildGameButton(
                    text: '¡Entrar a la partida!',
                    onTap: () async {
                      final username = _usernameCtrl.text.trim();
                      final password = _passwordCtrl.text.trim();

                      if (username.isEmpty || password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Por favor ingresa usuario y contraseña.',
                            ),
                          ),
                        );
                        return;
                      }

                      final ok = await auth.login(username, password);
                      if (ok) {
                        if (!mounted) return;
                        Navigator.pushReplacementNamed(context, '/lobby');
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Credenciales incorrectas.'),
                          ),
                        );
                      }
                    },
                  ),
                ),
        ),

        const SizedBox(height: 15),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¿No tienes cuenta?',
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text(
                'Crear cuenta',
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: baseGreen,
                  height: 1.5,
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────
  // PANEL PROFESOR
  // ────────────────────────────────────────────────

  Widget _buildProfesorPanel(Color baseGreen) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        // Más rápido: frecuencia alta
        final w = t * 2 * pi * 4.2;
        final bob = sin(w) * 10; // subir / bajar
        final tilt = sin(w) * 0.09; // inclinación más marcada

        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: baseGreen,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
            topLeft: Radius.circular(24),
          ),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0A6C59),
              Color(0xFF065A4B),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
            topLeft: Radius.circular(24),
          ),
          child: Stack(
            children: [
              // Badge de nivel arriba
              Positioned(
                top: 12,
                right: 18,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 0.7,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 14, color: Colors.amberAccent),
                      SizedBox(width: 3),
                      Text(
                        'Nivel Aula 1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // mini “ilustración” del juego
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF0DBA99), Color(0xFF0A7D66)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.school_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                      Positioned(
                        bottom: 8,
                        right: 18,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.95),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.casino_rounded,
                            size: 18,
                            color: Color(0xFF0A7D66),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 14,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.18),
                          ),
                          child: const Icon(
                            Icons.sentiment_very_dissatisfied_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    '¡El profe te espera!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Afila tu mente, lanza el dado\n'
                      'y demuestra quién manda en clase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────

  Widget _buildInput({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.pressStart2p(
        fontSize: 10,
        color: Colors.black87,
        height: 1.5,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF065A4B)),
        labelText: label,
        labelStyle: GoogleFonts.pressStart2p(
          fontSize: 10,
          color: Colors.black54,
          height: 1.5,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF065A4B), width: 1.6),
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildGameButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0DBA99), Color(0xFF0A7D66)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A7D66).withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.pressStart2p(
              fontSize: 11,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// PARTICLES MODEL + PAINTER
// ────────────────────────────────────────────────

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final Animation<double> animation;

  _ParticlesPainter({
    required this.particles,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Fondo con gradiente más vivo
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF065A4B), Color(0xFF022C22)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final paint = Paint()..style = PaintingStyle.fill;
    final t = animation.value;

    // Partículas pequeñas
    for (final p in particles) {
      final dy =
          (p.y * size.height + t * p.speed * size.height) % size.height;
      final dx =
          p.x * size.width + sin(t * 2 * pi * p.speed + p.x * 10) * 18;

      paint
        ..color = Colors.white.withOpacity(p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);
      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }

    // Glows grandes para dar efecto "bokeh gamer"
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    final glowCenters = [
      Offset(size.width * 0.2, size.height * 0.25),
      Offset(size.width * 0.8, size.height * 0.7),
      Offset(size.width * 0.5, size.height * 0.9),
    ];

    for (int i = 0; i < glowCenters.length; i++) {
      final offsetY = sin(t * 2 * pi * (0.8 + i * 0.3)) * 12;
      canvas.drawCircle(
        glowCenters[i] + Offset(0, offsetY),
        80 + i * 12,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

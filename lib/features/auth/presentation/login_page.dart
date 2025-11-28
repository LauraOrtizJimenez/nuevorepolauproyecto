import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  late AnimationController _bgController;
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

    // Animación de fondo (partículas)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    final rnd = Random();
    _particles = List.generate(40, (i) {
      return _Particle(
        x: rnd.nextDouble(), // 0..1
        y: rnd.nextDouble(), // 0..1
        radius: 2 + rnd.nextDouble() * 3,
        speed: 0.2 + rnd.nextDouble() * 0.8, // velocidad vertical
        opacity: 0.08 + rnd.nextDouble() * 0.12,
      );
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);

    const Color baseGreen = Color(0xFF065A4B);

    return Scaffold(
      body: Stack(
        children: [
          _buildAnimatedBackground(), // ⬅ partículas + íconos suaves

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
                            final profPanel = _buildProfesorPanel(baseGreen);

                            return isNarrow
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 16),
                                      SizedBox(height: 200, child: profPanel),
                                      const Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 18,
                                        ),
                                        child: form,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 24,
                                          ),
                                          child: form,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 260,
                                          child: profPanel,
                                        ),
                                      ),
                                    ],
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
  //               BACKGROUND ANIMADO
  // ────────────────────────────────────────────────

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Partículas + gradiente
        Positioned.fill(
          child: CustomPaint(
            painter: _ParticlesPainter(
              particles: _particles,
              animation: _bgController,
            ),
          ),
        ),

        // Íconos suaves fijos (temática juego / universidad)
        Positioned(
          top: 70,
          left: 40,
          child: _softIcon(Icons.school_rounded, 80),
        ),
        Positioned(
          top: 170,
          left: 140,
          child: _softIcon(Icons.groups_rounded, 70),
        ),
        Positioned(
          bottom: 150,
          right: 70,
          child: _softIcon(Icons.emoji_events_rounded, 70),
        ),
        Positioned(
          bottom: 70,
          left: 110,
          child: _softIcon(Icons.casino_rounded, 85),
        ),
        Positioned(
          top: 260,
          right: 90,
          child: _softIcon(Icons.sentiment_very_dissatisfied_rounded, 75),
        ),
        Positioned(
          top: 120,
          right: 40,
          child: _softIcon(Icons.menu_book_rounded, 60),
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

  // ────────────────────────────────────────────────
  //                 SECCIÓN DEL FORM
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
        Text(
          'Profesores y Matones',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: baseGreen,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Inicia sesión para entrar a la partida.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
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

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: auth.loading
              ? const Center(child: CircularProgressIndicator())
              : _buildGameButton(
                  text: 'Ingresar',
                  onTap: () async {
                    final username = _usernameCtrl.text.trim();
                    final password = _passwordCtrl.text;

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

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¿No tienes cuenta?',
              style: TextStyle(color: Colors.black54),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text(
                'Crear cuenta',
                style: TextStyle(
                  color: baseGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        )
      ],
    );
  }

  // ────────────────────────────────────────────────
  //                 PANEL DEL PROFE
  // ────────────────────────────────────────────────

  Widget _buildProfesorPanel(Color baseGreen) {
    return Container(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // mini “ilustración” del juego
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
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
                  size: 52,
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
                'Responde bien, esquiva a los profesores\n'
                'y llega primero a la meta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  //                    HELPERS
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
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF065A4B)),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
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
              color: const Color(0xFF0A7D66).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Ingresar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
//         MODELO Y PAINTER PARA PARTÍCULAS
// ────────────────────────────────────────────────

class _Particle {
  final double x; // 0..1
  final double y; // 0..1
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
    // Fondo con gradiente
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF065A4B), Color(0xFF044339)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final paint = Paint()..style = PaintingStyle.fill;
    final t = animation.value;

    for (final p in particles) {
      // Movimiento vertical + ligero movimiento horizontal sinusoidal
      final dy =
          (p.y * size.height + t * p.speed * size.height) % size.height;
      final dx = p.x * size.width +
          sin(t * 2 * pi * p.speed + p.x * 10) * 18;

      paint.color = Colors.white.withOpacity(p.opacity);
      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

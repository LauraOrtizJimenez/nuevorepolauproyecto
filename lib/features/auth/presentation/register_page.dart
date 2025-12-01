import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  late AnimationController _bgController;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    // Animación de entrada
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
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        radius: 2 + rnd.nextDouble() * 3,
        speed: 0.2 + rnd.nextDouble() * 0.8,
        opacity: 0.08 + rnd.nextDouble() * 0.12,
      );
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
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
  //           BACKGROUND ANIMADO (PARTÍCULAS)
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
              return CustomPaint(
                painter: _ParticlesPainter(
                  particles: _particles,
                  animation: _bgController,
                ),
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
      color: Colors.white.withOpacity(0.07),
    );
  }

  // ────────────────────────────────────────────────
  //                SECCIÓN DEL FORM
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
        // Botón para volver al login (por si entró por error)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              // Puedes usar pop si SIEMPRE vienes del login:
              // Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(
              'Volver al login',
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                height: 1.5,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: baseGreen,
            ),
          ),
        ),
        const SizedBox(height: 4),

        Text(
          'Crear cuenta',
          style: GoogleFonts.pressStart2p(
            fontSize: 18,
            color: baseGreen,
            letterSpacing: 1,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Regístrate para unirte a las partidas.',
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
          controller: _emailCtrl,
          icon: Icons.email_outlined,
          label: 'Email',
        ),
        const SizedBox(height: 10),

        _buildPasswordInput(
          controller: _passwordCtrl,
          icon: Icons.lock_outline,
          label: 'Contraseña',
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: auth.loading
              ? const Center(child: CircularProgressIndicator())
              : _buildGameButton(
                  text: 'Registrarme',
                  onTap: () async {
                    final username = _usernameCtrl.text.trim();
                    final email = _emailCtrl.text.trim();
                    final password = _passwordCtrl.text;

                    if (username.isEmpty ||
                        email.isEmpty ||
                        password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Completa usuario, email y contraseña.',
                          ),
                        ),
                      );
                      return;
                    }

                    final ok =
                        await auth.register(username, email, password);
                    if (ok) {
                      if (!mounted) return;
                      // Después de crear la cuenta, te mando al lobby
                      Navigator.pushReplacementNamed(context, '/lobby');
                    } else {
                      if (!mounted) return;
                      final msg =
                          auth.error ?? 'No se pudo registrar la cuenta.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
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
              '¿Ya tienes cuenta?',
              style: TextStyle(color: Colors.black54),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text(
                'Inicia sesión',
                style: TextStyle(
                  color: baseGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────
  //               PANEL DERECHA (PROFE)
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
              'Crea tu perfil jugador',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Elige bien tu usuario, los profesores\n'
                'y matones ya te están esperando.',
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
  //                      HELPERS
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

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required IconData icon,
    required String label,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
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
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF065A4B),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
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
    return _HoverButton(
      onTap: onTap,
      text: text,
    );
  }
}

// ────────────────────────────────────────────────
// HOVER BUTTON
// ────────────────────────────────────────────────

class _HoverButton extends StatefulWidget {
  final VoidCallback onTap;
  final String text;

  const _HoverButton({
    required this.onTap,
    required this.text,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isHovering
                  ? [const Color(0xFF065A4B), const Color(0xFF044234)] // Verde más oscuro
                  : [const Color(0xFF0DBA99), const Color(0xFF0A7D66)], // Verde normal
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
              widget.text,
              style: GoogleFonts.pressStart2p(
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
//            PARTÍCULAS Y PAINTER
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
      final dy =
          (p.y * size.height + t * p.speed * size.height) % size.height;
      final dx =
          p.x * size.width + sin(t * 2 * pi * p.speed + p.x * 10) * 18;

      paint.color = Colors.white.withOpacity(p.opacity);
      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

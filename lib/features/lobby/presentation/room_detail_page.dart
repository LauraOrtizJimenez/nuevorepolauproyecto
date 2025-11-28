import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/lobby_controller.dart';
import '../../auth/presentation/logout_button.dart';

class RoomDetailPage extends StatelessWidget {
  final String roomId;
  const RoomDetailPage({super.key, required this.roomId});

  static const Color _baseGreen = Color(0xFF065A4B);

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<LobbyController>(context, listen: false);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Detalles de la sala'),
        actions: const [LogoutButton()],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    color: Colors.white.withOpacity(0.97),
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header con icono
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0DBA99),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.meeting_room_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sala $roomId',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _baseGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Únete a esta sala para esperar a los demás jugadores y comenzar la partida.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Info de la sala
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID de sala',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF9F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        roomId,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _baseGreen,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: _baseGreen,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Comparte este ID si quieres que tus amigos entren a la misma sala.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Botón principal
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0DBA99),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                final ok = await ctrl.joinRoom(roomId);
                                if (ok) {
                                  // Si ya estabas en la sala no mostramos mensaje,
                                  // solo te mandamos directo a la sala de espera.
                                  if (!context.mounted) return;
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/rooms/$roomId/waiting',
                                  );
                                } else {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ctrl.error ??
                                            'No se pudo entrar a la sala',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Entrar a la sala',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Volver al lobby',
                              style: TextStyle(
                                color: _baseGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ FONDO TIPO JUEGO ------------------

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
          child: _softIcon(Icons.meeting_room_rounded, 70),
        ),
        Positioned(
          top: 160,
          right: 50,
          child: _softIcon(Icons.groups_rounded, 60),
        ),
        Positioned(
          bottom: 80,
          left: 80,
          child: _softIcon(Icons.casino_rounded, 70),
        ),
        Positioned(
          bottom: 40,
          right: 80,
          child: _softIcon(Icons.school_rounded, 60),
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
}

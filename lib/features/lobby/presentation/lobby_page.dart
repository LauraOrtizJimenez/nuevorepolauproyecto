import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/lobby_controller.dart';
import '../../auth/presentation/logout_button.dart';
import '../../../core/models/room_summary_dto.dart';
import '../../auth/state/auth_controller.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lobbyCtrl =
          Provider.of<LobbyController>(context, listen: false);
      lobbyCtrl.startPolling(intervalSeconds: 120);
      lobbyCtrl.loadRooms();

      // 👇 refrescamos perfil para traer coins reales del backend
      final authCtrl =
          Provider.of<AuthController>(context, listen: false);
      await authCtrl.refreshProfile();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Provider.of<LobbyController>(context, listen: false).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<LobbyController>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // AppBar invisible (solo deja la status bar)
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeaderRow(context, ctrl),
                  const SizedBox(height: 16),
                  _buildSearchCard(context, ctrl),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ctrl.loading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildRoomListCard(context, ctrl),
                  ),
                  const SizedBox(height: 16),
                  _buildCreateButton(context, ctrl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────
  //  BACKGROUND
  // ─────────────────────────────
  Widget _buildBackground() {
    return Container(
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
    );
  }

  Widget _softIcon(IconData icon, double size) {
    return Icon(
      icon,
      size: size,
      color: Colors.white.withOpacity(0.07),
    );
  }

  // ─────────────────────────────
  //  HEADER SUPERIOR
  // ─────────────────────────────
  Widget _buildHeaderRow(BuildContext context, LobbyController ctrl) {
    final auth = Provider.of<AuthController>(context);
    final coins = auth.coins;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF065A4B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Texto "Lobby" + descripción
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lobby',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Únete a una sala o crea una nueva\npara comenzar la partida.',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white70,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),

          // 💰 pill de monedas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 18,
                  color: Colors.yellow,
                ),
                const SizedBox(width: 4),
                Text(
                  '$coins',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // 🛒 botón tienda
          IconButton(
            tooltip: 'Tienda de skins',
            icon: const Icon(Icons.storefront, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/shop');
            },
          ),

          const SizedBox(width: 8),

          // 👉 Solo dejamos el LogoutButton, que ya maneja avatar/nombre a su manera
          const LogoutButton(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ─────────────────────────────
  //  SEARCH CARD
  // ─────────────────────────────
  Widget _buildSearchCard(BuildContext context, LobbyController ctrl) {
    return Card(
      color: Colors.white.withOpacity(0.95),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.pressStart2p(
                  fontSize: 11,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Buscar sala por ID',
                  hintText: 'Ingresa el ID de la sala',
                  labelStyle: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                  hintStyle: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 🔄 BOTÓN RECARGAR LISTA DE SALAS
            IconButton(
              tooltip: 'Recargar salas',
              icon: const Icon(Icons.refresh),
              onPressed: ctrl.loading
                  ? null
                  : () async {
                      await ctrl.loadRooms();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Salas actualizadas'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
            ),

            const SizedBox(width: 4),

            // 🔍 BOTÓN BUSCAR POR ID
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final id = _searchCtrl.text.trim();
                  if (id.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor ingresa un ID de sala'),
                      ),
                    );
                    return;
                  }

                  final room = await ctrl.getRoomById(id);
                  if (room != null) {
                    if (!mounted) return;
                    Navigator.pushNamed(context, '/rooms/${room.id}');
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se encontró la sala'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF065A4B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(
                      color: Color(0xFF044339),
                      width: 3,
                    ),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'BUSCAR',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 9,
                    height: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(1, 1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────
  //  LISTA DE SALAS
  // ─────────────────────────────
  Widget _buildRoomListCard(BuildContext context, LobbyController ctrl) {
    if (ctrl.rooms.isEmpty) {
      return Card(
        color: Colors.white.withOpacity(0.95),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Aún no hay salas creadas.\nCrea la primera sala para empezar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.pressStart2p(
                fontSize: 11,
                height: 1.8,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      color: Colors.white.withOpacity(0.96),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: ctrl.rooms.length,
        itemBuilder: (ctx, i) {
          final r = ctrl.rooms[i];

          final initials = r.name.isNotEmpty
              ? r.name
                  .trim()
                  .split(' ')
                  .where((s) => s.isNotEmpty)
                  .map((s) => s[0])
                  .take(2)
                  .join()
                  .toUpperCase()
              : "S";

          final currentPlayers = r.playerNames.length;
          final maxPlayers = r.maxPlayers;
          final bool isFull = currentPlayers >= maxPlayers;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _handleRoomTap(context, ctrl, r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isFull
                      ? Colors.red.withOpacity(0.06)
                      : Colors.green.withOpacity(0.04),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF065A4B),
                      child: Text(
                        initials,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.name,
                                  style: GoogleFonts.pressStart2p(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                r.isPrivate
                                    ? Icons.lock_outline
                                    : Icons.public_outlined,
                                size: 16,
                                color: Colors.grey[700],
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Jugadores: $currentPlayers / $maxPlayers',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 9,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: isFull
                            ? Colors.red.withOpacity(0.14)
                            : Colors.green.withOpacity(0.18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFull
                                ? Icons.block
                                : Icons.play_circle_outline,
                            size: 16,
                            color: isFull ? Colors.red : Colors.green[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFull ? 'Llena' : 'Disponible',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 9,
                              color: isFull
                                  ? Colors.red[800]
                                  : Colors.green[800],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────
  //  BOTÓN CREAR SALA
  // ─────────────────────────────
  Widget _buildCreateButton(BuildContext context, LobbyController ctrl) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          // Sombra oscura inferior (efecto 3D pixelado)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 20),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'CREAR SALA',
              style: GoogleFonts.pressStart2p(
                fontSize: 11,
                height: 1.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF065A4B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(
                color: Color(0xFF044339),
                width: 3,
              ),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: () => _showCreateDialog(context, ctrl),
        ),
      ),
    );
  }

  // ─────────────────────────────
  //  DIALOG CREAR SALA
  // ─────────────────────────────
  void _showCreateDialog(BuildContext context, LobbyController ctrl) {
    final nameCtrl = TextEditingController(
      text: 'Sala ${DateTime.now().millisecondsSinceEpoch % 1000}',
    );
    final codeCtrl = TextEditingController();

    int maxPlayers = 4;
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(
                'Crear sala',
                style: GoogleFonts.pressStart2p(fontSize: 12, height: 1.5),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la sala',
                      labelStyle: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Máximo de jugadores:',
                        style: GoogleFonts.pressStart2p(fontSize: 9, height: 1.5),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: maxPlayers,
                        items: [2, 3, 4, 6]
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  '$v',
                                  style: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setStateDialog(() {
                              maxPlayers = v;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(
                      'Sala privada',
                      style: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                    ),
                    contentPadding: EdgeInsets.zero,
                    value: isPrivate,
                    onChanged: (val) {
                      setStateDialog(() {
                        isPrivate = val;
                      });
                    },
                  ),
                  if (isPrivate)
                    TextField(
                      controller: codeCtrl,
                      style: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                      decoration: InputDecoration(
                        labelText: 'Código de acceso',
                        labelStyle: GoogleFonts.pressStart2p(fontSize: 10, height: 1.5),
                      ),
                      obscureText: true,
                    ),
                ],
              ),
              actions: [
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(
                          color: Colors.grey,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 9,
                        height: 1.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(1, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim();

                      if (name.isEmpty) return;
                      if (isPrivate && code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Ingresa un código para la sala privada'),
                          ),
                        );
                        return;
                      }

                      Navigator.of(ctx).pop();

                      final room = await ctrl.createRoom(
                        name,
                        maxPlayers: maxPlayers,
                        isPrivate: isPrivate,
                        accessCode: isPrivate ? code : null,
                      );

                      if (room == null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo crear la sala'),
                          ),
                        );
                        return;
                      }

                      if (!mounted) return;
                      Navigator.pushNamed(context, '/rooms/${room.id}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065A4B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(
                          color: Color(0xFF044339),
                          width: 3,
                        ),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'CREAR',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 9,
                        height: 1.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(1, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────
  //   TAP EN UNA SALA
  // ─────────────────────────────
  Future<void> _handleRoomTap(
      BuildContext context, LobbyController ctrl, RoomSummaryDto room) async {
    final currentPlayers = room.playerNames.length;
    final maxPlayers = room.maxPlayers;
    if (currentPlayers >= maxPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La sala está llena')),
      );
      return;
    }

    String? code;

    if (room.isPrivate) {
      final codeCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Text('Sala privada: ${room.name}'),
            content: TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Código de acceso',
              ),
              obscureText: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Unirse'),
              ),
            ],
          );
        },
      );

      if (ok != true) return;
      code = codeCtrl.text.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes ingresar un código')),
        );
        return;
      }
    }

    final success = await ctrl.joinRoom(room.id, accessCode: code);

    if (!mounted) return;

    if (!success) {
      if (ctrl.lastJoinInvalidCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código incorrecto para esta sala')),
        );
      } else if (ctrl.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ctrl.error!)),
        );
      }
      return;
    }

    Navigator.pushNamed(context, '/rooms/${room.id}');
  }
}

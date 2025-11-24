import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

import '../state/lobby_controller.dart';
import '../../../core/models/room_summary_dto.dart';
import '../../auth/presentation/logout_button.dart';
import '../../auth/state/auth_controller.dart';
import '../../game/state/game_controller.dart';
import '../../../core/api_client.dart';
import 'dart:convert';

class WaitingRoomPage extends StatefulWidget {
  final String roomId;
  const WaitingRoomPage({super.key, required this.roomId});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  Timer? _roomWatcherTimer;
  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<LobbyController>(context, listen: false);
    // load initial room info
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Do not auto-navigate to the game. Many deployments create the game
        // record before players are attached, which caused the app to open
        // an empty board. Show a notification and keep the room UI active.
        final r = await ctrl.getRoomById(widget.roomId);
        try { developer.log('WaitingRoom init for room=${widget.roomId} fetchedRoom=${r?.toString() ?? '<null>'}', name: 'WaitingRoomPage'); } catch (_) {}
        if (r != null && r.status != null && r.status!.toLowerCase().contains('ingame')) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room is in-game. Use "Enter Game" to join when ready.')));
        }

        // start polling so the waiting room updates automatically
        ctrl.startPolling(intervalSeconds: 1);

        // Watcher: refresh room info periodically and auto-enter when a game exists.
        // Behavior: prefer explicit gameId; attempt to load game and navigate. Wait
        // briefly for players to sync but still navigate even if players are empty
        // (user requested auto-join for everyone when the game is created).
        _roomWatcherTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
          try {
            final lobby = Provider.of<LobbyController>(context, listen: false);
            final refreshed = await lobby.getRoomById(widget.roomId);
            if (refreshed != null) {
              final bool hasGameFlag = (refreshed.status != null && refreshed.status!.toLowerCase().contains('ingame')) || (refreshed.gameId?.isNotEmpty ?? false);
              if (hasGameFlag) {
                final gameCtrl = Provider.of<GameController>(context, listen: false);
                bool loaded = false;
                // Prefer explicit game id
                final gid = refreshed.gameId;
                if (gid != null && gid.isNotEmpty) {
                  try {
                    loaded = await gameCtrl.loadGame(gid);
                  } catch (_) {
                    loaded = false;
                  }
                }
                // Fallback: try loading by room id
                if (!loaded) {
                  try {
                    loaded = await gameCtrl.loadGameByRoom(widget.roomId);
                  } catch (_) {
                    loaded = false;
                  }
                }

                if (loaded && gameCtrl.game != null) {
                  // Give server a short window to attach players, but navigate
                  // even if the players list remains empty (per user request).
                  for (int attempt = 0; attempt < 4; attempt++) {
                    if (gameCtrl.game != null && gameCtrl.game!.players.isNotEmpty) break;
                    await Future.delayed(const Duration(milliseconds: 300));
                    try { if (gameCtrl.game != null) await gameCtrl.loadGame(gameCtrl.game!.id); } catch (_) {}
                  }
                  if (!mounted) return;
                  _roomWatcherTimer?.cancel();
                  Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                  return;
                }
              }
            }
            if (mounted) setState(() {});
          } catch (e) {
            try { developer.log('WaitingRoom watcher error: ${e.toString()}', name: 'WaitingRoomPage'); } catch (_) {}
          }
        });
      } catch (e, st) {
        try { developer.log('WaitingRoom init error: ${e.toString()}\n$st', name: 'WaitingRoomPage'); } catch (_) {}
        if (mounted) {
          try { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WaitingRoom init error: ${e.toString()}'))); } catch (_) {}
        }
      }
      await _ensureJoinedIfNeeded();
    });
  }

  Future<void> _ensureJoinedIfNeeded() async {
    try {
      final lobby = Provider.of<LobbyController>(context, listen: false);
      final auth = Provider.of<AuthController>(context, listen: false);
      if (!auth.isLoggedIn) return;
      final username = auth.username ?? '';
      // Refresh room info first
      final r = await lobby.getRoomById(widget.roomId);
      if (r == null) return;
      if (username.isNotEmpty && !r.playerNames.map((s) => s.trim().toLowerCase()).contains(username.trim().toLowerCase())) {
        // Try to join up to a few times — some servers are eventually consistent
        bool joined = false;
        String? lastErr;
        for (int attempt = 0; attempt < 4 && !joined; attempt++) {
          try {
            final ok = await lobby.joinRoom(widget.roomId);
            if (ok) {
              joined = true;
              break;
            }
            lastErr = lobby.error;
          } catch (e) {
            lastErr = e.toString();
          }
          // Refresh room info before retrying
          try { await lobby.getRoomById(widget.roomId); } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (joined) {
          await lobby.getRoomById(widget.roomId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You were added to the room.')));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-join failed: ${lastErr ?? lobby.error}')));
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      final ctrl = Provider.of<LobbyController>(context, listen: false);
      ctrl.stopPolling();
      _roomWatcherTimer?.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lobby = Provider.of<LobbyController>(context);
    final gameCtrl = Provider.of<GameController>(context, listen: false);
    final auth = Provider.of<AuthController>(context, listen: false);

    final room = lobby.rooms.firstWhere((r) => r.id == widget.roomId, orElse: () => RoomSummaryDto(id: widget.roomId, name: 'Room', players: 0, maxPlayers: 0));

    final bool canStart = (room.players) >= 2;
    final bool isOwner = (room.ownerId != null && auth.userId != null && room.ownerId == auth.userId) || room.ownerId == null;

    return Scaffold(
      appBar: AppBar(title: Text('Waiting Room ${widget.roomId}'), actions: const [LogoutButton()]),
      body: Column(
        children: [
          // Gradient header with room title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF6FB1FF)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Players: ${room.players}/${room.maxPlayers}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 12),
                    if (room.ownerName != null) Chip(label: Text(room.ownerName!), backgroundColor: Colors.white24, labelStyle: const TextStyle(color: Colors.white)),
                  ],
                )
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Waiting players:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: room.playerNames.isNotEmpty
                            ? ListView.separated(
                                itemCount: room.playerNames.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, i) {
                                  final name = room.playerNames[i];
                                  final initials = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
                                  final isOwnerTile = room.ownerName != null && room.ownerName == name;
                                  final isMe = (auth.username != null && auth.username == name);
                                  return ListTile(
                                    leading: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(radius: 22, backgroundColor: isOwnerTile ? Colors.amber.shade700 : Theme.of(context).primaryColor.withOpacity(0.15)),
                                        CircleAvatar(radius: 18, backgroundColor: isOwnerTile ? Colors.amber : (isMe ? Colors.green : Theme.of(context).primaryColor), child: Text(initials, style: const TextStyle(color: Colors.white))),
                                      ],
                                    ),
                                    title: Text(name, style: TextStyle(fontWeight: isOwnerTile ? FontWeight.bold : FontWeight.normal)),
                                    subtitle: isMe ? const Text('You', style: TextStyle(color: Colors.green)) : null,
                                    trailing: isOwnerTile ? const Icon(Icons.star, color: Colors.amber) : null,
                                  );
                                },
                              )
                            : const Center(child: Text('No players joined yet.')),
                      ),

                      // Debug panel to help diagnose empty player lists
                      if (room.playerNames.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Debug info:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                              const SizedBox(height: 6),
                              if (lobby.error != null) Text('Last error: ${lobby.error}', style: const TextStyle(color: Colors.red)),
                              Text('Known rooms cached: ${lobby.rooms.length}', style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Fetch Room'),
                                    onPressed: () async {
                                      await lobby.getRoomById(widget.roomId);
                                      setState(() {});
                                      await _ensureJoinedIfNeeded();
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.sync),
                                    label: const Text('Fetch All Rooms'),
                                    onPressed: () async {
                                      await lobby.loadRooms();
                                      setState(() {});
                                    },
                                  ),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.code),
                                        label: const Text('Show Raw JSON'),
                                        onPressed: () async {
                                          try {
                                            final client = ApiClient();
                                            final raw = await client.getJson('/api/Lobby/rooms/${widget.roomId}');
                                            final pretty = const JsonEncoder.withIndent('  ').convert(raw);
                                            if (!mounted) return;
                                            showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Room JSON'), content: SingleChildScrollView(child: Text(pretty)), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))]));
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching raw JSON: ${e.toString()}')));
                                          }
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.bug_report),
                                        label: const Text('Show Diagnostics'),
                                        onPressed: () async {
                                          try {
                                            final gameCtrl = Provider.of<GameController>(context, listen: false);
                                            final details = StringBuffer();
                                            details.writeln('gameCtrl.error: ${gameCtrl.error}');
                                            details.writeln('lobby.error: ${lobby.error}');
                                            details.writeln('lastSignalRError: ${gameCtrl.lastSignalRError}');
                                            details.writeln('ApiClient.lastRequestSummary: ${ApiClient.lastRequestSummary}');
                                            details.writeln('ApiClient.lastResponseSummary: ${ApiClient.lastResponseSummary}');
                                            if (!mounted) return;
                                            showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Diagnostics'), content: SingleChildScrollView(child: Text(details.toString())), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))]));
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Diagnostics failed: ${e.toString()}')));
                                          }
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.login),
                                        label: const Text('Try Re-join'),
                                        onPressed: () async {
                                          final ok = await lobby.joinRoom(widget.roomId);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Join succeeded' : 'Join failed: ${lobby.error}')));
                                          await lobby.getRoomById(widget.roomId);
                                          setState(() {});
                                          await _ensureJoinedIfNeeded();
                                        },
                                      ),
                                ],
                              )
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            onPressed: () async {
                              await lobby.getRoomById(widget.roomId);
                              setState(() {});
                            },
                          ),
                          const SizedBox(width: 12),
                          // If a game is active for this room, allow entering directly
                          if ((room.status != null && room.status!.toLowerCase().contains('ingame')) || (room.gameId?.isNotEmpty ?? false))
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.videogame_asset),
                                label: const Text('Enter Game'),
                                onPressed: () async {
                                  // Attempt to load/join the active game for this room
                                  try {
                                    // Prefer explicit gameId
                                    if (room.gameId != null && room.gameId!.isNotEmpty) {
                                      final ok = await gameCtrl.loadGame(room.gameId!);
                                      if (ok && gameCtrl.game != null) {
                                        // Verify local player is present on the server-side game
                                        final prefs = Provider.of<AuthController>(context, listen: false);
                                        final localName = prefs.username ?? '';
                                        bool present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                        if (!present) {
                                          // Try to join the lobby room and also attempt to attach
                                          // to the existing game via `createOrJoinGame` which some
                                          // backends use to add an existing room player into the
                                          // active game. Retry a few times to handle eventual consistency.
                                          final lobby = Provider.of<LobbyController>(context, listen: false);
                                          for (int attempt = 0; attempt < 4 && !present; attempt++) {
                                            try { await lobby.joinRoom(widget.roomId); } catch (_) {}
                                            try { await lobby.getRoomById(widget.roomId); } catch (_) {}
                                            // Attempt to join the game explicitly (safe: server may
                                            // return existing game or add player to it).
                                            try { await gameCtrl.createOrJoinGame(roomId: widget.roomId); } catch (_) {}
                                            try { await gameCtrl.loadGame(room.gameId!); } catch (_) {}
                                            if (gameCtrl.game != null) {
                                              present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                            }
                                            if (present) break;
                                            await Future.delayed(const Duration(milliseconds: 500));
                                          }
                                        }

                                        if (present) {
                                          if (!mounted) return;
                                          Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                                          return;
                                        }
                                      }
                                    }

                                    // Try loading by roomId (some backends use the same id)
                                    final tryByRoom = await gameCtrl.loadGameByRoom(widget.roomId);
                                    if (tryByRoom && gameCtrl.game != null) {
                                      // Verify presence similarly
                                      final prefs = Provider.of<AuthController>(context, listen: false);
                                      final localName = prefs.username ?? '';
                                      bool present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                      if (!present) {
                                        final lobby = Provider.of<LobbyController>(context, listen: false);
                                        for (int attempt = 0; attempt < 4 && !present; attempt++) {
                                          try { await lobby.joinRoom(widget.roomId); } catch (_) {}
                                          try { await lobby.getRoomById(widget.roomId); } catch (_) {}
                                          // Try to attach to the active game if server requires
                                          // an explicit game join action.
                                          try { await gameCtrl.createOrJoinGame(roomId: widget.roomId); } catch (_) {}
                                          try { await gameCtrl.loadGameByRoom(widget.roomId); } catch (_) {}
                                          if (gameCtrl.game != null) {
                                            present = gameCtrl.game!.players.any((p) => p.username.trim().toLowerCase() == localName.trim().toLowerCase());
                                          }
                                          if (present) break;
                                          await Future.delayed(const Duration(milliseconds: 500));
                                        }
                                      }
                                      if (present) {
                                        if (!mounted) return;
                                        Navigator.pushReplacementNamed(context, '/game/${gameCtrl.game!.id}');
                                        return;
                                      }
                                    }

                                    // If we couldn't find a game for this room or local user isn't in it, inform the user
                                    if (!mounted) return;
                                    final details = <String>[];
                                    if (gameCtrl.error != null && gameCtrl.error!.isNotEmpty) details.add('gameErr=${gameCtrl.error}');
                                    if (lobby.error != null && lobby.error!.isNotEmpty) details.add('lobbyErr=${lobby.error}');
                                    final sigErr = gameCtrl.lastSignalRError;
                                    if (sigErr != null && sigErr.isNotEmpty) details.add('signalR=${sigErr}');
                                    final msg = (details.isNotEmpty) ? details.join(' | ') : 'No active game found for this room or you are not in the game yet.';
                                    developer.log('Enter Game failed: $msg', name: 'WaitingRoomPage');
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter game failed: ${e.toString()}')));
                                  }
                                },
                              ),
                            ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canStart ? Colors.green : Colors.grey,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(canStart ? 'Start Game' : 'Need more players'),
                            onPressed: (!canStart || !isOwner)
                                ? null
                                : () async {
                                    // Ensure AuthController finished loading (token present)
                                    final auth = Provider.of<AuthController>(context, listen: false);
                                    int waitAuth = 0;
                                    while (!auth.isLoggedIn && waitAuth < 15) {
                                      await Future.delayed(const Duration(milliseconds: 200));
                                      waitAuth++;
                                    }
                                    // Ensure local user is joined in the lobby before creating the game
                                    final prefs = Provider.of<AuthController>(context, listen: false);
                                    final localName = prefs.username ?? '';
                                    bool inRoom = false;
                                    try {
                                      final tryRoom = await lobby.getRoomById(widget.roomId);
                                      if (tryRoom != null) {
                                        inRoom = tryRoom.playerNames.map((s) => s.trim().toLowerCase()).contains(localName.trim().toLowerCase());
                                      }
                                    } catch (_) {}
                                    if (!inRoom) {
                                      // Try to join up to a few times before starting
                                      for (int attempt = 0; attempt < 6 && !inRoom; attempt++) {
                                        try {
                                          await lobby.joinRoom(widget.roomId);
                                        } catch (_) {}
                                        try {
                                          final refreshed = await lobby.getRoomById(widget.roomId);
                                          if (refreshed != null) {
                                            inRoom = refreshed.playerNames.map((s) => s.trim().toLowerCase()).contains(localName.trim().toLowerCase());
                                          }
                                        } catch (_) {}
                                        if (inRoom) break;
                                        await Future.delayed(const Duration(milliseconds: 400));
                                      }
                                    }

                                    // refresh before starting
                                    final r = await lobby.getRoomById(widget.roomId);
                                    if (r == null || (r.players < 2)) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Need at least 2 players to start the game.')));
                                      setState(() {});
                                      return;
                                    }

                                      // Try to create/join the game. If the server complains
                                      // about player counts, refresh the room a few times
                                      // and retry briefly to handle eventual consistency.
                                      bool created = false;
                                      String? lastErr;
                                      for (int attempt = 0; attempt < 4 && !created; attempt++) {
                                        final ok = await gameCtrl.createOrJoinGame(roomId: widget.roomId);
                                        if (ok && gameCtrl.game != null) {
                                          created = true;
                                          break;
                                        }
                                        lastErr = gameCtrl.error;
                                        // If server indicates missing players, refresh room and wait
                                        if (lastErr != null && lastErr.toLowerCase().contains('need at least')) {
                                          await lobby.getRoomById(widget.roomId);
                                          await Future.delayed(const Duration(milliseconds: 600));
                                          continue;
                                        }
                                        // For other errors, don't retry aggressively
                                        break;
                                      }
                                      if (created && gameCtrl.game != null) {
                                        // Ensure local player is present in the server game
                                        final prefs = Provider.of<AuthController>(context, listen: false);
                                        final localName = prefs.username ?? '';
                                        bool present = false;
                                        // Try a few short retries to wait for server to include the player
                                        for (int check = 0; check < 6 && !present; check++) {
                                          try {
                                            // Refresh room and attempt to load the game by room
                                            await lobby.getRoomById(widget.roomId);
                                            await gameCtrl.loadGameByRoom(widget.roomId);
                                          } catch (_) {}
                                          if (gameCtrl.game != null) {
                                            present = gameCtrl.game!.players.any((p) => (p.username.trim().toLowerCase() == localName.trim().toLowerCase()));
                                          }
                                          if (present) break;
                                          await Future.delayed(const Duration(milliseconds: 500));
                                        }
                                        if (!present) {
                                          // If still not present, show error so user knows join may have failed
                                          if (!mounted) return;
                                            // Show diagnostic dialog so user can copy request/response details
                                            final details = StringBuffer();
                                            details.writeln('gameCtrl.error: ${gameCtrl.error}');
                                            details.writeln('ApiClient.lastRequestSummary: ${ApiClient.lastRequestSummary}');
                                            details.writeln('ApiClient.lastResponseSummary: ${ApiClient.lastResponseSummary}');
                                            if (!mounted) return;
                                            showDialog(context: context, builder: (_) => AlertDialog(title: const Text('No se pudo confirmar que estés en la partida'), content: SingleChildScrollView(child: Text(details.toString())), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')), TextButton(onPressed: () { try { Clipboard.setData(ClipboardData(text: details.toString())); } catch(_){} Navigator.of(context).pop(); }, child: const Text('Copiar'))]));
                                        } else {
                                          final id = gameCtrl.game!.id;
                                          if (!mounted) return;
                                          Navigator.pushReplacementNamed(context, '/game/$id');
                                          return;
                                        }
                                      } else {
                                         final err = gameCtrl.error ?? lastErr ?? 'Failed to create game';
                                         if (!mounted) return;
                                         // Show more detailed dialog so user can copy diagnostics
                                         final details = StringBuffer();
                                         details.writeln('error: $err');
                                         details.writeln('gameCtrl.error: ${gameCtrl.error}');
                                         details.writeln('lobby.error: ${lobby.error}');
                                         details.writeln('ApiClient.lastRequestSummary: ${ApiClient.lastRequestSummary}');
                                         details.writeln('ApiClient.lastResponseSummary: ${ApiClient.lastResponseSummary}');
                                         showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Create Game Failed'), content: SingleChildScrollView(child: Text(details.toString())), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')), TextButton(onPressed: () { try { Clipboard.setData(ClipboardData(text: details.toString())); } catch(_){} Navigator.of(context).pop(); }, child: const Text('Copiar'))]));
                                      }
                                  },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

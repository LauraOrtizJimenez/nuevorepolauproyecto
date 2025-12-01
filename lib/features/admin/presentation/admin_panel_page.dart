import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/admin_service.dart';
import '../../auth/state/auth_controller.dart';
import '../state/admin_controller.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminController(AdminService()),
      child: const _AdminPanelView(),
    );
  }
}

class _AdminPanelView extends StatefulWidget {
  const _AdminPanelView();

  @override
  State<_AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends State<_AdminPanelView> {
  // --- controllers para coins ---
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController(text: '50');

  // --- controllers para crear skin ---
  final TextEditingController _skinNameCtrl = TextEditingController();
  final TextEditingController _colorKeyCtrl =
      TextEditingController(text: 'green');
  final TextEditingController _iconKeyCtrl =
      TextEditingController(text: 'hat');
  final TextEditingController _priceCtrl =
      TextEditingController(text: '100');

  bool _skinActive = true;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _amountCtrl.dispose();
    _skinNameCtrl.dispose();
    _colorKeyCtrl.dispose();
    _iconKeyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final username = (auth.username ?? '').toLowerCase().trim();

    // 🚫 Bloqueo duro en front: si no eres admin, no ves el panel
    if (username != 'admin') {
      return const Scaffold(
        body: Center(
          child: Text(
            'No autorizado.\nSolo el admin puede acceder a este panel.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final adminCtrl = context.watch<AdminController>();

    void showStatusSnackbars() {
      final error = adminCtrl.error;
      final success = adminCtrl.success;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else if (success != null && success.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──────────────────────────────
            // 1) Dar monedas a un usuario
            // ──────────────────────────────
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dar monedas a un usuario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ID de usuario',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de coins (+ o -)',
                        helperText: 'Puedes poner negativo para restar monedas',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: adminCtrl.loading
                            ? null
                            : () async {
                                final userId =
                                    int.tryParse(_userIdCtrl.text.trim()) ?? 0;
                                final amount =
                                    int.tryParse(_amountCtrl.text.trim()) ?? 0;

                                if (userId <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Ingresa un ID de usuario válido'),
                                    ),
                                  );
                                  return;
                                }

                                await context
                                    .read<AdminController>()
                                    .giveCoins(
                                      userId: userId,
                                      amount: amount,
                                    );

                                showStatusSnackbars();
                              },
                        icon: adminCtrl.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.monetization_on),
                        label: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ──────────────────────────────
            // 2) Crear nueva skin
            // ──────────────────────────────
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crear nueva skin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _skinNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la skin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _colorKeyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ColorKey (ej: green, red, blue)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _iconKeyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IconKey (ej: hat, star, skull)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Precio en coins',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Skin activa'),
                      value: _skinActive,
                      onChanged: (v) {
                        setState(() => _skinActive = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: adminCtrl.loading
                            ? null
                            : () async {
                                final name = _skinNameCtrl.text.trim();
                                final colorKey = _colorKeyCtrl.text.trim();
                                final iconKey = _iconKeyCtrl.text.trim();
                                final price =
                                    int.tryParse(_priceCtrl.text.trim()) ?? 0;

                                await context
                                    .read<AdminController>()
                                    .createSkin(
                                      name: name,
                                      colorKey: colorKey,
                                      iconKey: iconKey,
                                      priceCoins: price,
                                      isActive: _skinActive,
                                    );

                                showStatusSnackbars();
                              },
                        icon: adminCtrl.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_circle_outline),
                        label: const Text('Crear skin'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/token_skin_store_item.dart';
import '../../../core/services/skins_service.dart';
import '../../auth/state/auth_controller.dart';
import '../state/skins_store_controller.dart';

class ShopPage extends StatelessWidget {
  final int initialCoins;

  const ShopPage({super.key, this.initialCoins = 0});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final ctrl = SkinsStoreController(SkinsService());
        // Valor inicial (por si tarda el refresh)
        ctrl.setCoins(initialCoins);
        // Por defecto cargamos la TIENDA
        ctrl.loadStore();
        return ctrl;
      },
      child: const _ShopView(),
    );
  }
}

class _ShopView extends StatefulWidget {
  const _ShopView();

  @override
  State<_ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<_ShopView> {
  int _tabIndex = 0; // 0 = Tienda, 1 = Mis skins

  @override
  void initState() {
    super.initState();
    // Refrescar perfil para traer coins reales del backend
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthController>();
      await auth.refreshProfile();
      final skinsCtrl = context.read<SkinsStoreController>();
      skinsCtrl.setCoins(auth.coins);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final skinsCtrl = context.watch<SkinsStoreController>();

    // Fuente de verdad de las monedas
    final coins = auth.coins;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tienda de skins'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/lobby');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header con coins
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.yellow,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$coins',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.style_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Personaliza tu ficha',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tabs Tienda / Mis skins
                  _buildTabs(context),

                  const SizedBox(height: 12),

                  Expanded(
                    child: Card(
                      color: Colors.white.withOpacity(0.96),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildContentList(context, skinsCtrl, auth),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (skinsCtrl.loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------
  //  Tabs Tienda / Mis skins
  // ---------------------------------------------
  Widget _buildTabs(BuildContext context) {
    final skinsCtrl = context.read<SkinsStoreController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _buildTabButton(
            index: 0,
            label: 'Tienda',
            icon: Icons.storefront,
            onTap: () async {
              setState(() => _tabIndex = 0);
              await skinsCtrl.loadStore();
            },
          ),
          _buildTabButton(
            index: 1,
            label: 'Mis skins',
            icon: Icons.inventory_2_rounded,
            onTap: () async {
              setState(() => _tabIndex = 1);
              await skinsCtrl.loadOwnedSkins();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool selected = _tabIndex == index;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.9) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF065A4B) : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF065A4B) : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------
  //  Listado principal
  // ---------------------------------------------
  Widget _buildContentList(
    BuildContext context,
    SkinsStoreController skinsCtrl,
    AuthController auth,
  ) {
    if (skinsCtrl.error != null) {
      return Center(
        child: Text(
          skinsCtrl.error!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (skinsCtrl.items.isEmpty && !skinsCtrl.loading) {
      return Center(
        child: Text(
          _tabIndex == 0
              ? 'No hay skins en la tienda por ahora.'
              : 'Todavía no tienes skins compradas.',
          style: const TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      itemCount: skinsCtrl.items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 190,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, idx) {
        final item = skinsCtrl.items[idx];
        return _buildSkinCard(context, item, skinsCtrl, auth);
      },
    );
  }

  // ---------------------------------------------
  //  Tarjeta individual de skin
  // ---------------------------------------------
  Widget _buildSkinCard(
    BuildContext context,
    TokenSkinStoreItem item,
    SkinsStoreController skinsCtrl,
    AuthController auth,
  ) {
    final isOwned = item.isOwned;
    final isSelected = item.isSelected;
    final canBuy = !isOwned && auth.coins >= item.priceCoins;

    final color = _resolveColor(item.colorKey);
    final iconChar = _resolveIconChar(item.iconKey);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF0DBA99) : Colors.black12,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Preview ficha (mismo estilo que el tablero)
            CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Text(
                iconChar,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 16,
                  color: Colors.amber,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.priceCoins}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                )
              ],
            ),
            const SizedBox(height: 4),
            if (isOwned)
              Text(
                isSelected ? 'En uso' : 'Comprada',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? const Color(0xFF0DBA99)
                      : Colors.grey.shade600,
                ),
              ),
            const Spacer(),
            if (!isOwned && _tabIndex == 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canBuy
                      ? () async {
                          await skinsCtrl.buySkin(item);

                          if (skinsCtrl.error == null) {
                            await auth.refreshProfile();
                            skinsCtrl.setCoins(auth.coins);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Has comprado la skin "${item.name}"',
                                  ),
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(skinsCtrl.error!),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  child: const Text('Comprar'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isSelected
                      ? null
                      : () async {
                          await skinsCtrl.selectSkin(item);

                          if (skinsCtrl.error == null) {
                            await auth.setSelectedSkin(
                              colorKey: item.colorKey,
                              iconKey: item.iconKey,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Ahora estás usando "${item.name}"',
                                  ),
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(skinsCtrl.error!),
                                ),
                              );
                            }
                          }
                        },
                  child: Text(isSelected ? 'Seleccionada' : 'Usar'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------
  //  Helpers: colores e iconos por key (alineado con GameBoard)
  // ---------------------------------------------
  Color _resolveColor(String? key) {
    if (key == null || key.isEmpty) {
      return const Color(0xFF4A90E2);
    }
    final lower = key.toLowerCase().trim();

    switch (lower) {
      case 'red':
      case 'rojo':
        return Colors.redAccent;
      case 'blue':
      case 'azul':
        return Colors.blueAccent;
      case 'green':
      case 'verde':
        return Colors.green;
      case 'yellow':
      case 'amarillo':
        return Colors.yellow.shade700;
      case 'purple':
      case 'morado':
        return Colors.purpleAccent;
      case 'pink':
      case 'rosa':
        return Colors.pinkAccent;
      case 'orange':
      case 'naranja':
        return Colors.deepOrangeAccent;

      // mismas que en GameBoardWidget
      case 'dark_blue':
        return const Color(0xFF003366);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'steel_gray':
        return const Color(0xFF607D8B);
      case 'neon_purple':
        return const Color(0xFFB000FF);

      default:
        return const Color(0xFF4A90E2);
    }
  }

  /// Devuelve un char/emoji para mostrar en el preview.
  String _resolveIconChar(String? key) {
    if (key == null || key.isEmpty) {
      return '⭐';
    }

    final trimmed = key.trim();
    final lower = trimmed.toLowerCase();

    // Nombres lógicos
    switch (lower) {
      case 'nerd':
        return '🤓';
      case 'angry':
        return '😡';
      case 'cool':
        return '😎';
      case 'classic':
        return 'C';
    }

    // Si ya es emoji (💎, 👑, 🛡️, ⭐, 🔮, etc.), lo usamos tal cual
    final hasNonAscii = RegExp(r'[^\x00-\x7F]').hasMatch(trimmed);
    if (hasNonAscii) return trimmed;

    // Fallback a estrella
    return '⭐';
  }

  // ---------------------------------------------
  //  Fondo tipo lobby/juego
  // ---------------------------------------------
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
          top: 70,
          left: 40,
          child: Icon(
            Icons.storefront_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        Positioned(
          top: 150,
          right: 40,
          child: Icon(
            Icons.casino_rounded,
            size: 70,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 60,
          child: Icon(
            Icons.style_rounded,
            size: 70,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ],
    );
  }
}

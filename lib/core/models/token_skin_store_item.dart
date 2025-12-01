class TokenSkinStoreItem {
  final int id;
  final String name;
  final String colorKey;
  final String iconKey;
  final int priceCoins;
  final bool isOwned;
  final bool isSelected;

  const TokenSkinStoreItem({
    required this.id,
    required this.name,
    required this.colorKey,
    required this.iconKey,
    required this.priceCoins,
    required this.isOwned,
    required this.isSelected,
  });

  factory TokenSkinStoreItem.fromJson(Map<String, dynamic> json) {
    return TokenSkinStoreItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      colorKey: json['colorKey'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? '',
      priceCoins: json['priceCoins'] as int? ?? 0,
      isOwned: json['isOwned'] as bool? ?? false,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }
}

import '../../core/constants/app_enums.dart';

class ShopItem {
  final String id;
  final ShopItemType type;
  final String title;
  final String description;
  final String icon;
  final int gemCost;

  const ShopItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.gemCost,
  });
}

/// Hearts are deliberately absent from the shop: they refill at the
/// start of every lesson, so there is nothing to sell.
const List<ShopItem> shopCatalog = [
  ShopItem(
    id: 'streak_freeze',
    type: ShopItemType.streakFreeze,
    title: 'Streak Freeze',
    description: 'Protects your streak for one missed day',
    icon: 'ac_unit',
    gemCost: 200,
  ),
  ShopItem(
    id: 'mascot_outfit',
    type: ShopItemType.mascotOutfit,
    title: 'Spark Outfit',
    description: 'A cosmetic look for your Spark companion',
    icon: 'auto_awesome',
    gemCost: 500,
  ),
];

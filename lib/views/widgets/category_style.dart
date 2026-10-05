import 'package:flutter/material.dart';

/// Colour and icon for a category, derived from its name because the API
/// stores neither. The hue comes from a stable hash of the name, so the same
/// category looks the same everywhere; the icon comes from keywords in
/// Polish and English, with a hashed fallback.
class CategoryStyle {
  const CategoryStyle({
    required this.container,
    required this.onContainer,
    required this.accent,
    required this.icon,
  });

  /// Soft background for an avatar or chip.
  final Color container;

  /// Icon or text colour on [container].
  final Color onContainer;

  /// A saturated mid tone for small marks such as a dot in the table.
  final Color accent;
  final IconData icon;

  static CategoryStyle of(BuildContext context, String name) =>
      forBrightness(name, Theme.of(context).brightness);

  static CategoryStyle forBrightness(String name, Brightness brightness) {
    final hash = _hash(name);
    final hue = (hash % 360).toDouble();
    final light = brightness == Brightness.light;
    return CategoryStyle(
      container: HSLColor.fromAHSL(1, hue, light ? 0.55 : 0.40, light ? 0.86 : 0.30).toColor(),
      onContainer: HSLColor.fromAHSL(1, hue, light ? 0.60 : 0.55, light ? 0.28 : 0.86).toColor(),
      accent: HSLColor.fromAHSL(1, hue, 0.60, light ? 0.48 : 0.64).toColor(),
      icon: iconFor(name, hash),
    );
  }

  static int _hash(String name) {
    var hash = 7;
    for (final unit in name.trim().toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  /// First keyword match wins; a name without one gets a neutral icon
  /// chosen by hash so it stays stable.
  static IconData iconFor(String name, [int? hash]) {
    final lower = name.toLowerCase();
    for (final entry in _keywords) {
      if (entry.keys.any(lower.contains)) return entry.icon;
    }
    final h = hash ?? _hash(name);
    return _fallbackIcons[h % _fallbackIcons.length];
  }

  static const _keywords = <({List<String> keys, IconData icon})>[
    (keys: ['jedz', 'food', 'grocer', 'spoż', 'zakup', 'sklep', 'market'], icon: Icons.shopping_basket_outlined),
    (keys: ['restaur', 'kaw', 'coffee', 'pizza', 'lunch', 'obiad', 'knajp'], icon: Icons.restaurant_outlined),
    (keys: ['paliw', 'fuel', 'samoch', 'auto', 'car', 'parking'], icon: Icons.directions_car_outlined),
    (keys: ['transport', 'bilet', 'bus', 'pociąg', 'train', 'metro', 'taxi', 'uber', 'komunik'], icon: Icons.directions_bus_outlined),
    (keys: ['czynsz', 'rent', 'mieszk', 'dom', 'home', 'flat'], icon: Icons.home_outlined),
    (keys: ['zdrow', 'health', 'apte', 'pharm', 'lekar', 'doctor', 'dentyst', 'leki'], icon: Icons.medical_services_outlined),
    (keys: ['rozryw', 'kino', 'cinema', 'gry', 'game', 'entertain', 'koncert'], icon: Icons.theaters_outlined),
    (keys: ['ubran', 'cloth', 'odzie', 'buty', 'shoe'], icon: Icons.checkroom_outlined),
    (keys: ['sport', 'gym', 'siłow', 'fitness', 'basen'], icon: Icons.fitness_center_outlined),
    (keys: ['eduk', 'szko', 'ksią', 'book', 'kurs', 'course', 'studi'], icon: Icons.school_outlined),
    (keys: ['prezent', 'gift'], icon: Icons.card_giftcard_outlined),
    (keys: ['podró', 'travel', 'wakac', 'holiday', 'hotel', 'flight', 'urlop'], icon: Icons.flight_outlined),
    (keys: ['prąd', 'energ', 'gaz', 'woda', 'water', 'electric', 'rachun', 'bill', 'opłat'], icon: Icons.bolt_outlined),
    (keys: ['internet', 'telefon', 'phone', 'mobile', 'abonament'], icon: Icons.wifi_outlined),
    (keys: ['subskryp', 'subscr', 'netflix', 'spotify', 'stream'], icon: Icons.subscriptions_outlined),
    (keys: ['zwierz', 'pet', 'pies', 'dog'], icon: Icons.pets_outlined),
    (keys: ['dzieci', 'kid', 'child', 'baby', 'niemowl'], icon: Icons.child_care_outlined),
    (keys: ['uroda', 'beauty', 'fryzj', 'hair', 'kosmet'], icon: Icons.spa_outlined),
    (keys: ['oszcz', 'saving', 'invest', 'inwest'], icon: Icons.savings_outlined),
    (keys: ['praca', 'work', 'biuro', 'office'], icon: Icons.work_outline),
    (keys: ['inne', 'other', 'różne', 'misc'], icon: Icons.category_outlined),
  ];

  static const _fallbackIcons = [
    Icons.local_offer_outlined,
    Icons.bookmark_outline,
    Icons.star_outline,
    Icons.label_outline,
    Icons.shopping_bag_outlined,
    Icons.payments_outlined,
    Icons.widgets_outlined,
    Icons.sell_outlined,
  ];
}

/// Round avatar with the category's icon on its colour.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.name, this.radius = 18});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(context, name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: style.container,
      child: Icon(style.icon, size: radius, color: style.onContainer),
    );
  }
}

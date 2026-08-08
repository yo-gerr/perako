import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

/// Preset color names available to accounts and categories. The database only
/// stores the name (or a hex string like `#RRGGBB` for custom colors);
/// rendering maps the name to a [Color].
const List<String> colorChoices = [
  'teal',
  'blue',
  'green',
  'orange',
  'purple',
  'red',
  'brown',
  'grey',
];

/// The legacy curated icon names stored in the database.
const List<String> iconChoices = [
  'wallet',
  'account_balance',
  'savings',
  'credit_card',
  'cash',
  'trending_up',
  'home',
  'work',
  'piggy_bank',
  'coins',
  'sack_dollar',
  'scale_balance',
  'building_columns',
  'landmark',
  'cart',
  'car',
  'burger',
  'utensils',
  'graduation_cap',
  'heart_pulse',
  'plane',
  'gift',
  'bullseye',
  'percent',
];

/// An icon pickable by the user. [name] is what gets stored in the database;
/// [icon] is the glyph rendered for it.
typedef IconOption = ({String name, FaIconData icon});

/// The full icon library offered in the icon picker bottom sheet.
const List<IconOption> iconCatalog = [
  // Material classics.
  (name: 'wallet', icon: FaIconData(Icons.account_balance_wallet)),
  (name: 'account_balance', icon: FaIconData(Icons.account_balance)),
  (name: 'savings', icon: FaIconData(Icons.savings)),
  (name: 'credit_card', icon: FaIconData(Icons.credit_card)),
  (name: 'cash', icon: FaIconData(Icons.payments)),
  (name: 'trending_up', icon: FaIconData(Icons.trending_up)),
  (name: 'home', icon: FaIconData(Icons.home)),
  (name: 'work', icon: FaIconData(Icons.work)),

  // Money & finance.
  (name: 'piggy_bank', icon: FontAwesomeIcons.piggyBank),
  (name: 'coins', icon: FontAwesomeIcons.coins),
  (name: 'sack_dollar', icon: FontAwesomeIcons.sackDollar),
  (name: 'money_bill', icon: FontAwesomeIcons.moneyBill),
  (name: 'money_bill_trend_up', icon: FontAwesomeIcons.moneyBillTrendUp),
  (name: 'money_check_dollar', icon: FontAwesomeIcons.moneyCheckDollar),
  (name: 'hand_holding_dollar', icon: FontAwesomeIcons.handHoldingDollar),
  (name: 'hand_holding_droplet', icon: FontAwesomeIcons.handHoldingDroplet),
  (name: 'scale_balance', icon: FontAwesomeIcons.scaleBalanced),
  (name: 'building_columns', icon: FontAwesomeIcons.buildingColumns),
  (name: 'landmark', icon: FontAwesomeIcons.landmark),
  (name: 'vault', icon: FontAwesomeIcons.vault),
  (name: 'receipt', icon: FontAwesomeIcons.receipt),
  (name: 'file_invoice', icon: FontAwesomeIcons.fileInvoice),
  (name: 'chart_line', icon: FontAwesomeIcons.chartLine),
  (name: 'chart_pie', icon: FontAwesomeIcons.chartPie),
  (name: 'calculator', icon: FontAwesomeIcons.calculator),
  (name: 'bullseye', icon: FontAwesomeIcons.bullseye),
  (name: 'percent', icon: FontAwesomeIcons.percent),
  (name: 'gift', icon: FontAwesomeIcons.gift),
  (name: 'tag', icon: FontAwesomeIcons.tag),
  (name: 'tags', icon: FontAwesomeIcons.tags),

  // Shopping.
  (name: 'cart', icon: FontAwesomeIcons.cartShopping),
  (name: 'bag_shopping', icon: FontAwesomeIcons.bagShopping),
  (name: 'basket_shopping', icon: FontAwesomeIcons.basketShopping),
  (name: 'box_open', icon: FontAwesomeIcons.boxOpen),
  (name: 'truck_fast', icon: FontAwesomeIcons.truckFast),

  // Food & drink.
  (name: 'burger', icon: FontAwesomeIcons.burger),
  (name: 'utensils', icon: FontAwesomeIcons.utensils),
  (name: 'pizza_slice', icon: FontAwesomeIcons.pizzaSlice),
  (name: 'apple_whole', icon: FontAwesomeIcons.appleWhole),
  (name: 'mug_hot', icon: FontAwesomeIcons.mugHot),
  (name: 'cake', icon: FontAwesomeIcons.cakeCandles),
  (name: 'ice_cream', icon: FontAwesomeIcons.iceCream),
  (name: 'martini_glass', icon: FontAwesomeIcons.martiniGlass),

  // Home & living.
  (name: 'house_chimney', icon: FontAwesomeIcons.houseChimney),
  (name: 'bed', icon: FontAwesomeIcons.bed),
  (name: 'couch', icon: FontAwesomeIcons.couch),
  (name: 'door_open', icon: FontAwesomeIcons.doorOpen),
  (name: 'lightbulb', icon: FontAwesomeIcons.lightbulb),
  (name: 'plug', icon: FontAwesomeIcons.plug),
  (name: 'key', icon: FontAwesomeIcons.key),
  (name: 'tv', icon: FontAwesomeIcons.tv),

  // Transport.
  (name: 'car', icon: FontAwesomeIcons.car),
  (name: 'train', icon: FontAwesomeIcons.train),
  (name: 'bus', icon: FontAwesomeIcons.bus),
  (name: 'motorcycle', icon: FontAwesomeIcons.motorcycle),
  (name: 'bicycle', icon: FontAwesomeIcons.bicycle),
  (name: 'gas_pump', icon: FontAwesomeIcons.gasPump),
  (name: 'truck', icon: FontAwesomeIcons.truck),

  // Travel & outdoors.
  (name: 'plane', icon: FontAwesomeIcons.plane),
  (name: 'suitcase', icon: FontAwesomeIcons.suitcase),
  (name: 'tent', icon: FontAwesomeIcons.tent),
  (name: 'tree', icon: FontAwesomeIcons.tree),
  (name: 'mountain_sun', icon: FontAwesomeIcons.mountainSun),
  (name: 'umbrella_beach', icon: FontAwesomeIcons.umbrellaBeach),
  (name: 'compass', icon: FontAwesomeIcons.compass),
  (name: 'globe', icon: FontAwesomeIcons.globe),

  // Health.
  (name: 'heart_pulse', icon: FontAwesomeIcons.heartPulse),
  (name: 'stethoscope', icon: FontAwesomeIcons.stethoscope),
  (name: 'hospital', icon: FontAwesomeIcons.hospital),
  (name: 'syringe', icon: FontAwesomeIcons.syringe),
  (name: 'tooth', icon: FontAwesomeIcons.tooth),
  (name: 'bone', icon: FontAwesomeIcons.bone),
  (name: 'pills', icon: FontAwesomeIcons.pills),

  // Education.
  (name: 'graduation_cap', icon: FontAwesomeIcons.graduationCap),
  (name: 'school', icon: FontAwesomeIcons.school),
  (name: 'book', icon: FontAwesomeIcons.book),
  (name: 'pen', icon: FontAwesomeIcons.pen),
  (name: 'ruler', icon: FontAwesomeIcons.ruler),
  (name: 'flask', icon: FontAwesomeIcons.flask),

  // Work & tech.
  (name: 'briefcase', icon: FontAwesomeIcons.briefcase),
  (name: 'laptop', icon: FontAwesomeIcons.laptop),
  (name: 'diagram_project', icon: FontAwesomeIcons.diagramProject),
  (name: 'mobile_screen', icon: FontAwesomeIcons.mobileScreen),
  (name: 'headphones', icon: FontAwesomeIcons.headphones),

  // Entertainment.
  (name: 'gamepad', icon: FontAwesomeIcons.gamepad),
  (name: 'film', icon: FontAwesomeIcons.film),
  (name: 'music', icon: FontAwesomeIcons.music),
  (name: 'camera', icon: FontAwesomeIcons.camera),
  (name: 'dice', icon: FontAwesomeIcons.dice),

  // People & family.
  (name: 'users', icon: FontAwesomeIcons.users),
  (name: 'user', icon: FontAwesomeIcons.user),
  (name: 'baby', icon: FontAwesomeIcons.baby),
  (name: 'child', icon: FontAwesomeIcons.child),
  (name: 'heart', icon: FontAwesomeIcons.heart),
  (name: 'handshake', icon: FontAwesomeIcons.handshake),

  // Everyday & seasonal.
  (name: 'bolt', icon: FontAwesomeIcons.bolt),
  (name: 'star', icon: FontAwesomeIcons.star),
  (name: 'bell', icon: FontAwesomeIcons.bell),
  (name: 'bookmark', icon: FontAwesomeIcons.bookmark),
  (name: 'clock', icon: FontAwesomeIcons.clock),
  (name: 'calendar', icon: FontAwesomeIcons.calendar),
  (name: 'envelope', icon: FontAwesomeIcons.envelope),
  (name: 'leaf', icon: FontAwesomeIcons.leaf),
  (name: 'fire', icon: FontAwesomeIcons.fire),
  (name: 'snowflake', icon: FontAwesomeIcons.snowflake),
  (name: 'umbrella', icon: FontAwesomeIcons.umbrella),
  (name: 'paw', icon: FontAwesomeIcons.paw),
];

final Map<String, FaIconData> _iconByName = {
  // Legacy alias kept for any row that still stores it.
  'restaurant': FontAwesomeIcons.utensils,
  for (final option in iconCatalog) option.name: option.icon,
};

Color colorFromName(String name) {
  final hex = tryParseHexColor(name);
  if (hex != null) return hex;
  return switch (name) {
    'blue' => Colors.blue,
    'green' => Colors.green,
    'orange' => Colors.orange,
    'purple' => Colors.purple,
    'red' => Colors.red,
    'brown' => Colors.brown,
    'grey' => Colors.blueGrey,
    _ => Colors.teal,
  };
}

/// Whether [name] is a custom hex color (e.g. `#RRGGBB`, `0xRRGGBB`, or
/// `RRGGBB`) instead of a preset color name.
bool isHexColor(String name) => tryParseHexColor(name) != null;

/// Encodes an opaque color as `#RRGGBB` for storage in the database.
String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Parses a color string stored in the database: `#RRGGBB`, `0xRRGGBB`, or a
/// bare `RRGGBB`. Returns null for anything else.
Color? tryParseHexColor(String raw) {
  var hex = raw;
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  } else if (hex.startsWith('0x') || hex.startsWith('0X')) {
    hex = hex.substring(2);
  }
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Maps a stored icon name to an [FaIconData] renderable by [FaIcon].
FaIconData iconFromName(String name) =>
    _iconByName[name] ?? const FaIconData(Icons.account_balance_wallet);

/// A human-friendly label for an icon name, used for the picker's search.
String iconSearchLabel(String name) => name.replaceAll('_', ' ');

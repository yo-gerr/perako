import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:perako/features/accounts/presentation/account_style.dart';

void main() {
  test('every icon choice maps to a real glyph', () {
    for (final name in iconChoices) {
      final icon = iconFromName(name);
      expect(icon.codePoint, isNot(0), reason: '$name must resolve');
    }
  });

  test('icon choices are unique', () {
    expect(iconChoices.toSet(), hasLength(iconChoices.length));
  });

  test('material names keep their original icons', () {
    expect(iconFromName('wallet').data, Icons.account_balance_wallet);
    expect(iconFromName('account_balance').data, Icons.account_balance);
    expect(iconFromName('savings').data, Icons.savings);
    expect(iconFromName('credit_card').data, Icons.credit_card);
    expect(iconFromName('cash').data, Icons.payments);
    expect(iconFromName('trending_up').data, Icons.trending_up);
    expect(iconFromName('home').data, Icons.home);
    expect(iconFromName('work').data, Icons.work);
  });

  test('font awesome names map to font awesome icons', () {
    expect(iconFromName('piggy_bank'), FontAwesomeIcons.piggyBank);
    expect(iconFromName('coins'), FontAwesomeIcons.coins);
    expect(iconFromName('sack_dollar'), FontAwesomeIcons.sackDollar);
    expect(iconFromName('scale_balance'), FontAwesomeIcons.scaleBalanced);
    expect(iconFromName('building_columns'), FontAwesomeIcons.buildingColumns);
    expect(iconFromName('landmark'), FontAwesomeIcons.landmark);
    expect(iconFromName('cart'), FontAwesomeIcons.cartShopping);
    expect(iconFromName('car'), FontAwesomeIcons.car);
    expect(iconFromName('burger'), FontAwesomeIcons.burger);
    expect(iconFromName('utensils'), FontAwesomeIcons.utensils);
    expect(iconFromName('graduation_cap'), FontAwesomeIcons.graduationCap);
    expect(iconFromName('heart_pulse'), FontAwesomeIcons.heartPulse);
    expect(iconFromName('plane'), FontAwesomeIcons.plane);
    expect(iconFromName('gift'), FontAwesomeIcons.gift);
    expect(iconFromName('bullseye'), FontAwesomeIcons.bullseye);
    expect(iconFromName('percent'), FontAwesomeIcons.percent);
  });

  test('legacy and unknown names fall back to the default icon', () {
    expect(iconFromName('restaurant'), FontAwesomeIcons.utensils);
    expect(iconFromName('category').data, Icons.account_balance_wallet);
    expect(iconFromName('nope').data, Icons.account_balance_wallet);
  });

  test('the icon catalog is large, unique, and fully resolvable', () {
    expect(iconCatalog.length, greaterThanOrEqualTo(100));
    final names = [for (final option in iconCatalog) option.name];
    expect(names.toSet(), hasLength(names.length));
    for (final option in iconCatalog) {
      expect(iconFromName(option.name).codePoint, isNot(0),
          reason: '${option.name} must resolve');
      expect(iconSearchLabel(option.name), isNot(contains('_')));
    }
  });

  test('every legacy icon choice exists in the catalog', () {
    final names = [for (final option in iconCatalog) option.name];
    for (final name in iconChoices) {
      expect(names, contains(name));
    }
  });

  test('colorFromName accepts preset names', () {
    expect(colorFromName('teal'), Colors.teal);
    expect(colorFromName('blue'), Colors.blue);
    expect(colorFromName('green'), Colors.green);
    expect(colorFromName('orange'), Colors.orange);
    expect(colorFromName('purple'), Colors.purple);
    expect(colorFromName('red'), Colors.red);
    expect(colorFromName('brown'), Colors.brown);
    expect(colorFromName('grey'), Colors.blueGrey);
    expect(colorFromName('nope'), Colors.teal);
  });

  test('colorFromName is hex-aware', () {
    expect(colorFromName('#FF0000'), const Color(0xFFFF0000));
    expect(colorFromName('0x00FF00'), const Color(0xFF00FF00));
    expect(colorFromName('0000FF'), const Color(0xFF0000FF));
  });

  test('tryParseHexColor handles the supported forms', () {
    expect(tryParseHexColor('#FF0000'), const Color(0xFFFF0000));
    expect(tryParseHexColor('0x00FF00'), const Color(0xFF00FF00));
    expect(tryParseHexColor('0000FF'), const Color(0xFF0000FF));
    expect(tryParseHexColor('teal'), isNull);
    expect(tryParseHexColor('#FFF'), isNull);
    expect(tryParseHexColor('#GGGGGG'), isNull);
    expect(tryParseHexColor(''), isNull);
  });

  test('isHexColor only reports hex strings', () {
    expect(isHexColor('#FF0000'), isTrue);
    expect(isHexColor('FF0000'), isTrue);
    expect(isHexColor('0xFF0000'), isTrue);
    expect(isHexColor('teal'), isFalse);
    expect(isHexColor('green'), isFalse);
  });

  test('colorToHex round-trips through tryParseHexColor', () {
    const color = Color(0xFF123456);
    expect(colorToHex(color), '#123456');
    expect(tryParseHexColor(colorToHex(color)), color);
  });
}

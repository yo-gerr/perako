import 'package:flutter/material.dart';

/// Preset color names available to accounts and categories. The database only
/// stores the name; rendering maps the name to a [Color].
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

/// Preset icon names stored in the database.
const List<String> iconChoices = [
  'wallet',
  'account_balance',
  'savings',
  'credit_card',
  'cash',
  'trending_up',
  'home',
  'work',
];

Color colorFromName(String name) => switch (name) {
      'blue' => Colors.blue,
      'green' => Colors.green,
      'orange' => Colors.orange,
      'purple' => Colors.purple,
      'red' => Colors.red,
      'brown' => Colors.brown,
      'grey' => Colors.blueGrey,
      _ => Colors.teal,
    };

IconData iconFromName(String name) => switch (name) {
      'account_balance' => Icons.account_balance,
      'savings' => Icons.savings,
      'credit_card' => Icons.credit_card,
      'cash' => Icons.payments,
      'trending_up' => Icons.trending_up,
      'home' => Icons.home,
      'work' => Icons.work,
      _ => Icons.account_balance_wallet,
    };

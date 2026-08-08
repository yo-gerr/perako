import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/router/app_destinations.dart';

void main() {
  group('app destinations', () {
    test('covers all 14 branches in order', () {
      expect(allDestinations.length, 14);
      expect(
        allDestinations.map((d) => d.branchIndex).toList(),
        [for (var i = 0; i < 14; i++) i],
      );
    });

    test('paths are unique and match the shell branches', () {
      final paths = allDestinations.map((d) => d.path).toSet();
      expect(paths.length, allDestinations.length);

      expect(allDestinations[0].path, '/');
      expect(allDestinations[1].path, '/accounts');
      expect(allDestinations[2].path, '/transactions');
      expect(allDestinations[3].path, '/categories');
      expect(allDestinations[4].path, '/budgets');
      expect(allDestinations[5].path, '/bills');
      expect(allDestinations[6].path, '/goals');
      expect(allDestinations[7].path, '/time-deposits');
      expect(allDestinations[8].path, '/mp2');
      expect(allDestinations[9].path, '/bonds');
      expect(allDestinations[10].path, '/reports');
      expect(allDestinations[11].path, '/search');
      expect(allDestinations[12].path, '/settings');
      expect(allDestinations[13].path, '/more');
    });

    test('grouped lists reference the same destinations', () {
      expect(
        primaryDestinations.map((d) => d.label).toList(),
        ['Dashboard', 'Accounts', 'Transactions'],
      );
      expect(toolDestinations.length, 9);
      expect(settingsDestination.branchIndex, 12);
      expect(moreDestination.branchIndex, 13);
      expect(settingsDestination, same(allDestinations[12]));
      expect(moreDestination, same(allDestinations[13]));
    });
  });
}

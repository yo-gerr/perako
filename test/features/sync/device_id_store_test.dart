import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perako/features/sync/data/device_id_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('generates and persists a device id', () async {
    final store = const DeviceIdStore();
    final id = await store.loadOrCreate();

    expect(id, isNotEmpty);
    expect(id, startsWith('dev_'));

    // A second call returns the same, persisted id.
    final again = await store.loadOrCreate();
    expect(again, id);
  });

  test('loads an existing stored device id without regenerating', () async {
    SharedPreferences.setMockInitialValues({'perako.device_id': 'dev_existing'});
    final id = await const DeviceIdStore().loadOrCreate();
    expect(id, 'dev_existing');
  });
}
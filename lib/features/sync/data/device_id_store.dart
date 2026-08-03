import 'package:shared_preferences/shared_preferences.dart';

/// Generates and persists a stable per-install device id.
///
/// The id is stored in [SharedPreferences] (outside the drift DB), so it
/// survives sign-out and the local-database wipe. This is what makes the sync
/// engine's own-echo dedup work across a user's multiple devices: each install
/// has a distinct `writer` id.
class DeviceIdStore {
  const DeviceIdStore();

  static const _key = 'perako.device_id';

  /// Returns the existing id, or generates and persists a new one.
  Future<String> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final fresh = _newDeviceId();
    await prefs.setString(_key, fresh);
    return fresh;
  }

  /// Generate a distinct id without pulling in a uuid package.
  String _newDeviceId() {
    final rand = DateTime.now().microsecondsSinceEpoch;
    final suffix = rand.toRadixString(16).padLeft(12, '0');
    return 'dev_$suffix';
  }
}
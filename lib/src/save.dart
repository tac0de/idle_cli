import 'package:clock/clock.dart';
import 'package:idle_save/idle_save.dart';

class IdleCliSave {
  static SaveManager<Map<String, dynamic>> managerForPath({
    required String path,
    String? backupPath,
    required int nowMs,
  }) {
    return SaveManager<Map<String, dynamic>>(
      store: FileStore(path),
      backupStore: backupPath == null ? null : FileStore(backupPath),
      codec: const CanonicalJsonSaveCodec(),
      migrator: Migrator(latestVersion: 1),
      encoder: (value) => value,
      decoder: (payload) => payload,
      clock: Clock.fixed(DateTime.fromMillisecondsSinceEpoch(nowMs)),
    );
  }
}

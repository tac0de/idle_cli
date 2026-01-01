import 'package:clock/clock.dart';
import 'package:idle_save/idle_save.dart';

/// Helpers for creating `idle_save` managers used by the CLI.
class IdleCliSave {
  /// Creates a [SaveManager] configured for deterministic, portable JSON saves.
  ///
  /// The returned manager uses canonical JSON encoding and a fixed clock based
  /// on [nowMs] (typically the snapshot's `lastSeenMs`).
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

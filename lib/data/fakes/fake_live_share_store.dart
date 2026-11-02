import '../../domain/entities/live_share.dart';
import '../../domain/ports/live_share_store.dart';

/// In-memory [LiveShareStore] for tests and keyless runs.
class FakeLiveShareStore implements LiveShareStore {
  LiveShareSession? session;

  int saves = 0;
  int clears = 0;

  @override
  Future<LiveShareSession?> load() async => session;

  @override
  Future<void> save(LiveShareSession session) async {
    this.session = session;
    saves++;
  }

  @override
  Future<void> clear() async {
    session = null;
    clears++;
  }
}

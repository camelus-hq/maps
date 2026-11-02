import '../../domain/ports/external_actions.dart';

/// In-memory [ExternalActions] for tests and keyless runs.
///
/// Records every request so a test (or the control channel) can assert what the
/// UI tried to open, without leaving the app.
class FakeExternalActions implements ExternalActions {
  /// Phone numbers passed to [call], in order.
  final List<String> calls = <String>[];

  /// Addresses passed to [email] (`subject` kept separately), in order.
  final List<String> emails = <String>[];

  /// URLs passed to [openWebsite], in order.
  final List<String> websites = <String>[];

  /// What every call reports; set `false` to exercise the "nothing opened"
  /// branch.
  bool available = true;

  @override
  Future<bool> call(String phone) async {
    calls.add(phone);
    return available;
  }

  @override
  Future<bool> email(String address, {String? subject}) async {
    emails.add(address);
    return available;
  }

  @override
  Future<bool> openWebsite(String url) async {
    websites.add(url);
    return available;
  }
}

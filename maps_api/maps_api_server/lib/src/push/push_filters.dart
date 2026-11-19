import 'push_config.dart';

/// Builds the relay `REQ` filters for the set of registered public keys.
///
/// Watching every gift wrap on a public relay would be a firehose (kind 1059 is
/// used by every NIP-17 client) and rude to the relays, so the forwarder asks
/// only for events addressed to someone who registered: `{"kinds":[...],
/// "#p":[<pubkeys>]}`. The pubkey list is chunked because relays cap how many
/// values a filter may carry.
///
/// Returns a map of subscription id to filter. An empty map means nobody is
/// registered and the forwarder should watch nothing.
Map<String, Map<String, Object>> buildPushFilters(List<String> pubkeys) {
  final List<String> unique = <String>{
    for (final String pubkey in pubkeys)
      if (pubkey.length == 64) pubkey.toLowerCase(),
  }.toList(growable: false);
  if (unique.isEmpty) {
    return const <String, Map<String, Object>>{};
  }

  final List<int> kinds = PushConfig.availableKinds;
  final int chunk = PushConfig.pubkeysPerFilter;
  final Map<String, Map<String, Object>> filters =
      <String, Map<String, Object>>{};
  for (int start = 0; start < unique.length; start += chunk) {
    final int end = (start + chunk).clamp(0, unique.length);
    final int index = start ~/ chunk;
    filters['${PushConfig.subscriptionId}-$index'] = <String, Object>{
      'kinds': kinds,
      '#p': unique.sublist(start, end),
      'limit': 0,
    };
  }
  return filters;
}

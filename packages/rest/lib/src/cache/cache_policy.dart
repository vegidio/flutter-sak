class CachePolicy {
  final bool enabled;
  final Duration ttl;
  final int maxEntries;

  const CachePolicy({this.enabled = false, this.ttl = const Duration(seconds: 60), this.maxEntries = 100});
}

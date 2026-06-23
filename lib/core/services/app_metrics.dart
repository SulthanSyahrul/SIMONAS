import 'package:flutter/foundation.dart';

class AppRead {
  final String collection;
  final String operation;
  final int documentCount;
  final bool fromCache;
  final Duration latency;
  final DateTime timestamp;

  const AppRead({
    required this.collection,
    required this.operation,
    required this.documentCount,
    required this.fromCache,
    required this.latency,
    required this.timestamp,
  });
}

class AppMetrics {
  static final AppMetrics _instance = AppMetrics._internal();

  factory AppMetrics() => _instance;

  AppMetrics._internal();

  final List<AppRead> reads = <AppRead>[];
  final Map<String, _CollectionMetrics> _byCollection =
      <String, _CollectionMetrics>{};
  final Map<String, Duration> _screenLoadTimes = <String, Duration>{};
  final Map<String, int> _cacheHitsByCollection = <String, int>{};
  final Map<String, int> _cacheLookupsByCollection = <String, int>{};

  Duration? _startupDuration;
  DateTime? _startupStartedAt;

  void markStartupStarted() {
    _startupStartedAt ??= DateTime.now();
  }

  void markStartupCompleted() {
    final startedAt = _startupStartedAt;
    if (startedAt == null) {
      return;
    }
    _startupDuration = DateTime.now().difference(startedAt);
    if (kDebugMode) {
      debugPrint('[perf] startup=${_startupDuration!.inMilliseconds}ms');
    }
  }

  void recordScreenLoad(String screenName, Duration duration) {
    _screenLoadTimes[screenName] = duration;
    if (kDebugMode) {
      debugPrint('[perf] screen:$screenName=${duration.inMilliseconds}ms');
    }
  }

  void recordCacheLookup({
    required String collection,
    required bool hit,
  }) {
    _cacheLookupsByCollection.update(collection, (value) => value + 1,
        ifAbsent: () => 1);
    if (hit) {
      _cacheHitsByCollection.update(collection, (value) => value + 1,
          ifAbsent: () => 1);
    }
  }

  void recordRead({
    required String collection,
    required String operation,
    required int documentCount,
    required bool fromCache,
    required Duration latency,
  }) {
    final read = AppRead(
      collection: collection,
      operation: operation,
      documentCount: documentCount,
      fromCache: fromCache,
      latency: latency,
      timestamp: DateTime.now(),
    );

    reads.add(read);
    final metrics = _byCollection.putIfAbsent(
      collection,
      () => _CollectionMetrics(),
    );
    metrics.recordRead(read);
  }

  int get totalQueryCount => reads.length;

  double getCacheHitRate() {
    final totalLookups = _cacheLookupsByCollection.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (totalLookups == 0) {
      return 0;
    }

    final totalHits = _cacheHitsByCollection.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return totalHits / totalLookups;
  }

  Map<String, Duration> getAverageLatency() {
    final grouped = <String, List<Duration>>{};
    for (final read in reads) {
      grouped.putIfAbsent(read.operation, () => <Duration>[]);
      grouped[read.operation]!.add(read.latency);
    }

    final averages = <String, Duration>{};
    for (final entry in grouped.entries) {
      final totalMs = entry.value.fold<int>(
        0,
        (sum, value) => sum + value.inMilliseconds,
      );
      averages[entry.key] = Duration(
        milliseconds: (totalMs / entry.value.length).round(),
      );
    }
    return averages;
  }

  void printMetrics() {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[perf] startupMs=${_startupDuration?.inMilliseconds ?? -1}');
    debugPrint('[perf] queryCount=$totalQueryCount');
    debugPrint(
      '[perf] cacheHitRate=${(getCacheHitRate() * 100).toStringAsFixed(1)}%',
    );

    for (final entry in _byCollection.entries) {
      debugPrint(
        '[perf] collection=${entry.key} reads=${entry.value.readCount} '
        'avgLatencyMs=${entry.value.averageLatency.inMilliseconds}',
      );
    }

    for (final entry in _screenLoadTimes.entries) {
      debugPrint(
        '[perf] screen=${entry.key} loadMs=${entry.value.inMilliseconds}',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'startupMs': _startupDuration?.inMilliseconds,
      'queryCount': totalQueryCount,
      'cacheHitRate': getCacheHitRate(),
      'screenLoadTimesMs': _screenLoadTimes.map(
        (key, value) => MapEntry(key, value.inMilliseconds),
      ),
      'averageLatencyMs': getAverageLatency().map(
        (key, value) => MapEntry(key, value.inMilliseconds),
      ),
      'byCollection': _byCollection.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  void reset() {
    reads.clear();
    _byCollection.clear();
    _screenLoadTimes.clear();
    _cacheHitsByCollection.clear();
    _cacheLookupsByCollection.clear();
    _startupDuration = null;
    _startupStartedAt = null;
  }
}

class _CollectionMetrics {
  int readCount = 0;
  final List<Duration> latencies = <Duration>[];

  void recordRead(AppRead read) {
    readCount++;
    latencies.add(read.latency);
  }

  Duration get averageLatency {
    if (latencies.isEmpty) {
      return Duration.zero;
    }

    final totalMs = latencies.fold<int>(
      0,
      (sum, value) => sum + value.inMilliseconds,
    );
    return Duration(milliseconds: (totalMs / latencies.length).round());
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'readCount': readCount,
      'averageLatencyMs': averageLatency.inMilliseconds,
    };
  }
}

class PerfTimer {
  final String label;
  final Stopwatch _stopwatch = Stopwatch()..start();

  PerfTimer(this.label);

  Duration get elapsed => _stopwatch.elapsed;

  int get elapsedMs => _stopwatch.elapsedMilliseconds;

  void stop() {
    _stopwatch.stop();
    if (kDebugMode) {
      debugPrint('[perf] $label=${elapsedMs}ms');
    }
  }

  void stopIfSlow({int thresholdMs = 100}) {
    _stopwatch.stop();
    if (kDebugMode && elapsedMs > thresholdMs) {
      debugPrint('[perf] slow:$label=${elapsedMs}ms threshold=$thresholdMs');
    }
  }
}

class BatchTimer {
  final String label;
  final Stopwatch _total = Stopwatch()..start();
  final List<(String name, Duration duration)> operations =
      <(String name, Duration duration)>[];

  BatchTimer(this.label);

  Future<T> time<T>(String operationName, Future<T> Function() fn) async {
    final timer = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      timer.stop();
      operations.add((operationName, timer.elapsed));
    }
  }

  Duration get total => _total.elapsed;

  void stop() {
    _total.stop();
    if (!kDebugMode) {
      return;
    }

    debugPrint('[perf] batch:$label totalMs=${total.inMilliseconds}');
    for (final (name, duration) in operations) {
      debugPrint('[perf] batch:$label op:$name=${duration.inMilliseconds}ms');
    }
  }
}

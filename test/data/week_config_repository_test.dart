import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pku_manager/data/app_database.dart';
import 'package:pku_manager/data/week_config_parser.dart';
import 'package:pku_manager/data/week_config_repository.dart';
import 'package:pku_manager/domain/semester.dart';
import 'package:pku_manager/domain/week_source.dart';

const _valid = 'base_date = ["2026-09-07"]\ntimezone = "Asia/Shanghai"';
const _replacement = 'base_date = ["2027-02-22"]\ntimezone = "Asia/Shanghai"';

// Only the socket boundary is substituted: production redirect, byte-limit,
// UTF-8, parser, cache and SQLite transaction code all run unchanged.
class _Client implements HttpClient {
  _Client(this.respond);
  final Future<HttpClientResponse> Function(Uri) respond;
  final urls = <Uri>[];
  final requests = <_Request>[];
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    final request = _Request(() => respond(url));
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) => closed = force;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.respond);
  final Future<HttpClientResponse> Function() respond;
  @override
  bool followRedirects = true;
  @override
  Future<HttpClientResponse> close() => respond();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  _Headers(this.location);
  final String? location;
  @override
  String? value(String name) =>
      name == HttpHeaders.locationHeader ? location : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(String body, {this.statusCode = 200, int? length, String? location})
    : chunks = Stream.value(utf8.encode(body)),
      contentLength = length ?? utf8.encode(body).length,
      headers = _Headers(location);
  _Response.stream(this.chunks)
    : contentLength = -1,
      statusCode = 200,
      headers = _Headers(null);
  final Stream<List<int>> chunks;
  @override
  final int statusCode;
  @override
  final int contentLength;
  @override
  final HttpHeaders headers;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => chunks.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 9, 14, 12);
  late WeekConfigRepository repository;
  setUp(() {
    db = AppDatabase(':memory:');
    repository = WeekConfigRepository(
      db,
      WeekConfigParser(SemesterConfig()),
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  void seed({String content = _valid, String? timestamp}) {
    db.database.execute('INSERT OR REPLACE INTO week_cache VALUES (1, ?, ?)', [
      content,
      timestamp ?? now.toIso8601String(),
    ]);
  }

  List<Object?> cache() => db.database
      .select('SELECT content, fetched_at FROM week_cache')
      .map((r) => [r['content'], r['fetched_at']])
      .toList();
  Future<WeekStatus> refresh(_Client client) => HttpOverrides.runZoned(
    repository.refresh,
    createHttpClient: (_) => client,
  );

  test('HTTP success persists exact content and UTC timestamp; reads need no network', () async {
    final client = _Client((_) async => _Response(_valid));
    expect(repository.cached().freshness, WeekFreshness.unavailable);
    final result = await refresh(client);
    expect(result.freshness, WeekFreshness.fresh);
    expect(result.calendar!.starts, [DateTime.utc(2026, 9, 7)]);
    expect(cache(), [
      [_valid, now.toIso8601String()],
    ]);
    expect(repository.cached().freshness, WeekFreshness.cached);
    expect(
      client.urls.single.toString(),
      'https://parksnoopy-undergraduate.github.io/week/config.toml',
    );
    expect(client.requests.single.followRedirects, isFalse);
    expect(client.closed, isTrue);
  });

  for (final age in [
    Duration.zero,
    const Duration(days: 7),
    const Duration(days: 7, microseconds: 1),
    const Duration(seconds: -1),
  ]) {
    test('cache age boundary $age', () {
      seed(timestamp: now.subtract(age).toIso8601String());
      expect(
        repository.cached().freshness,
        age.isNegative || age > const Duration(days: 7)
            ? WeekFreshness.stale
            : WeekFreshness.cached,
      );
      expect(repository.cached().calendar, isNotNull);
    });
  }

  for (final corrupt in ['invalid content', 'invalid timestamp']) {
    test('$corrupt is unavailable and a valid refresh repairs it', () async {
      seed(
        content: corrupt == 'invalid content' ? 'not TOML' : _valid,
        timestamp: corrupt == 'invalid timestamp' ? 'not a date' : null,
      );
      expect(repository.cached().calendar, isNull);
      expect(repository.cached().freshness, WeekFreshness.unavailable);
      expect(
        (await refresh(_Client((_) async => _Response(_valid)))).freshness,
        WeekFreshness.fresh,
      );
      expect(repository.cached().freshness, WeekFreshness.cached);
    });
  }

  final failures = <String, Future<HttpClientResponse> Function(Uri)>{
    'invalid calendar date': (_) async =>
        _Response(_valid.replaceFirst('09-07', '02-30')),
    'duplicate dates': (_) async => _Response(
      _valid.replaceFirst('"2026-09-07"', '"2026-09-07", "2026-09-07"'),
    ),
    'HTTP 503': (_) async => _Response('unavailable', statusCode: 503),
    'connection failure': (_) async => throw const SocketException('offline'),
    'declared oversized response': (_) async =>
        _Response(_valid, length: 16385),
    'chunked oversized response': (_) async => _Response.stream(
      Stream.fromIterable([List.filled(8192, 32), List.filled(8193, 32)]),
    ),
    'broken response stream': (_) async =>
        _Response.stream(Stream.error(const HttpException('interrupted'))),
    'invalid UTF-8': (_) async => _Response.stream(Stream.value([0xff])),
    'cross-host redirect': (_) async => _Response(
      '',
      statusCode: 302,
      location: 'https://example.com/config.toml',
    ),
    'HTTP downgrade': (_) async => _Response(
      '',
      statusCode: 302,
      location: 'http://parksnoopy-undergraduate.github.io/config.toml',
    ),
    'missing redirect location': (_) async => _Response('', statusCode: 302),
    'redirect loop': (_) async =>
        _Response('', statusCode: 302, location: '/config.toml'),
  };
  for (final failure in failures.entries) {
    for (final hasCache in [false, true]) {
      test(
        '${failure.key}, existing cache=$hasCache: no publication',
        () async {
          if (hasCache) seed();
          final before = cache();
          final client = _Client(failure.value);
          final result = await refresh(client);
          expect(
            result.freshness,
            hasCache ? WeekFreshness.stale : WeekFreshness.unavailable,
          );
          expect(
            result.calendar?.starts,
            hasCache ? [DateTime.utc(2026, 9, 7)] : null,
          );
          expect(result.message, isNotEmpty);
          expect(cache(), before);
          expect(client.closed, isTrue);
          expect(client.urls.length, failure.key == 'redirect loop' ? 4 : 1);
        },
      );
    }
  }

  test('stale cache is replaced by successful refresh', () async {
    seed(timestamp: now.subtract(const Duration(days: 8)).toIso8601String());
    expect(repository.cached().freshness, WeekFreshness.stale);
    expect(
      (await refresh(_Client((_) async => _Response(_replacement)))).freshness,
      WeekFreshness.fresh,
    );
    expect(cache(), [
      [_replacement, now.toIso8601String()],
    ]);
    expect(repository.cached().freshness, WeekFreshness.cached);
  });

  test('exactly 16 KiB is accepted, including chunked transfer', () async {
    final prefix = '$_valid\n#';
    final body =
        prefix + List.filled(16384 - utf8.encode(prefix).length, ' ').join();
    final bytes = utf8.encode(body);
    expect(bytes, hasLength(16384));
    final client = _Client(
      (_) async => _Response.stream(
        Stream.fromIterable([bytes.sublist(0, 8192), bytes.sublist(8192)]),
      ),
    );
    expect((await refresh(client)).freshness, WeekFreshness.fresh);
    expect(cache(), [
      [body, now.toIso8601String()],
    ]);
    expect(client.closed, isTrue);
  });

  test('same-origin relative redirect reaches validated content', () async {
    final client = _Client(
      (uri) async => uri.path == '/week/config.toml'
          ? _Response('', statusCode: 302, location: '/new.toml')
          : _Response(_valid),
    );
    expect((await refresh(client)).freshness, WeekFreshness.fresh);
    expect(client.urls.map((u) => u.path), ['/week/config.toml', '/new.toml']);
    expect(client.requests.every((r) => !r.followRedirects), isTrue);
    expect(client.closed, isTrue);
  });

  test(
    'SQLite abort retains cache and releases transaction for retry',
    () async {
      seed();
      final before = cache();
      db.database.execute(
        "CREATE TRIGGER fail_cache BEFORE UPDATE ON week_cache BEGIN SELECT RAISE(ABORT, 'test fault'); END;",
      );
      expect(
        (await refresh(_Client((_) async => _Response(_replacement))))
            .freshness,
        WeekFreshness.stale,
      );
      expect(cache(), before);
      db.database.execute('DROP TRIGGER fail_cache');
      expect(
        (await refresh(_Client((_) async => _Response(_replacement))))
            .freshness,
        WeekFreshness.fresh,
      );
      expect(cache(), [
        [_replacement, now.toIso8601String()],
      ]);
    },
  );

  test(
    'concurrent refreshes share HTTP and publication, then permit a new fetch',
    () async {
      final response = Completer<HttpClientResponse>();
      final client = _Client((_) => response.future);
      await HttpOverrides.runZoned(() async {
        final first = repository.refresh();
        final second = repository.refresh();
        expect(identical(first, second), isTrue);
        response.complete(_Response(_valid));
        final results = await Future.wait([first, second]);
        expect(
          results.every((r) => r.freshness == WeekFreshness.fresh),
          isTrue,
        );
        expect(client.urls, hasLength(1));
        expect(cache(), hasLength(1));
      }, createHttpClient: (_) => client);
      final next = _Client((_) async => _Response(_replacement));
      expect((await refresh(next)).freshness, WeekFreshness.fresh);
      expect(next.urls, hasLength(1));
    },
  );

  test(
    'injected fetch enforces UTF-8 bytes rather than character count',
    () async {
      seed();
      final before = cache();
      final body = '$_valid\n#${List.filled(6000, '中').join()}';
      repository = WeekConfigRepository(
        db,
        WeekConfigParser(SemesterConfig()),
        fetch: () async => body,
        clock: () => now,
      );
      expect(body.length, lessThan(16384));
      expect((await repository.refresh()).freshness, WeekFreshness.stale);
      expect(cache(), before);
    },
  );
}

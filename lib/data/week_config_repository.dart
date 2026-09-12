import 'dart:convert';
import 'dart:io';

import '../domain/week_source.dart';
import 'app_database.dart';
import 'week_config_parser.dart';

class WeekConfigRepository implements WeekSource {
  WeekConfigRepository(
    this.database,
    this.parser, {
    Future<String> Function()? fetch,
    DateTime Function()? clock,
  }) : fetch = fetch ?? fetchPublicConfiguration,
       clock = clock ?? DateTime.now;
  final AppDatabase database;
  final WeekConfigParser parser;
  final Future<String> Function() fetch;
  final DateTime Function() clock;
  Future<WeekStatus>? _refresh;

  @override
  WeekStatus cached() {
    try {
      final rows = database.database.select(
        'SELECT content, fetched_at FROM week_cache WHERE id = 1',
      );
      if (rows.isEmpty) {
        return const WeekStatus(null, WeekFreshness.unavailable);
      }
      final row = rows.first;
      final age = clock().toUtc().difference(
        DateTime.parse(row['fetched_at'] as String),
      );
      return WeekStatus(
        parser.parse(row['content'] as String),
        age.isNegative || age > const Duration(days: 7)
            ? WeekFreshness.stale
            : WeekFreshness.cached,
      );
    } catch (_) {
      return const WeekStatus(
        null,
        WeekFreshness.unavailable,
        message: 'Stored week configuration is invalid.',
      );
    }
  }

  @override
  Future<WeekStatus> refresh() =>
      _refresh ??= _fetch().whenComplete(() => _refresh = null);

  Future<WeekStatus> _fetch() async {
    try {
      final text = await fetch().timeout(const Duration(seconds: 12));
      if (utf8.encode(text).length > 16384) {
        throw const FormatException('Week configuration exceeds 16 KiB');
      }
      final calendar = parser.parse(text);
      database.transaction(
        () => database.database.execute(
          '''
INSERT INTO week_cache VALUES (1, ?, ?) ON CONFLICT(id)
DO UPDATE SET content=excluded.content, fetched_at=excluded.fetched_at''',
          [text, clock().toUtc().toIso8601String()],
        ),
      );
      return WeekStatus(calendar, WeekFreshness.fresh);
    } catch (_) {
      final previous = cached();
      return WeekStatus(
        previous.calendar,
        previous.calendar == null
            ? WeekFreshness.unavailable
            : WeekFreshness.stale,
        message: 'Week refresh failed.',
      );
    }
  }

  static Future<String> fetchPublicConfiguration() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        var uri = Uri.parse(
          'https://parksnoopy-undergraduate.github.io/week/config.toml',
        );
        for (var redirects = 0; redirects <= 3; redirects++) {
          final request = await client.getUrl(uri);
          request.followRedirects = false;
          final response = await request.close();
          if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
            final location = response.headers.value(HttpHeaders.locationHeader);
            if (location == null) {
              throw const FormatException('Missing redirect location');
            }
            uri = uri.resolve(location);
            if (uri.scheme != 'https' ||
                uri.host != 'parksnoopy-undergraduate.github.io' ||
                uri.port != 443 ||
                uri.userInfo.isNotEmpty) {
              throw const FormatException('Redirect outside allowed host');
            }
            continue;
          }
          if (response.statusCode != 200 || response.contentLength > 16384) {
            throw const FormatException('Invalid week configuration response');
          }
          final bytes = <int>[];
          await for (final chunk in response) {
            if (bytes.length + chunk.length > 16384) {
              throw const FormatException('Week configuration exceeds 16 KiB');
            }
            bytes.addAll(chunk);
          }
          return utf8.decode(bytes);
        }
        throw const FormatException('Too many redirects');
      })().timeout(const Duration(seconds: 10));
    } finally {
      client.close(force: true);
    }
  }
}

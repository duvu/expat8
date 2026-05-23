import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner = 'duvu';
const _repo = 'expat8';
const _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';
const _cacheTagKey = 'github_release_latest_tag';
const _cacheUrlKey = 'github_release_latest_url';
const _cacheTimestampKey = 'github_release_last_checked_ms';
const _cacheMaxAge = Duration(hours: 1);

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseUrl,
  });

  final bool hasUpdate;
  final String? latestVersion;
  final String? releaseUrl;

  static const noUpdate = UpdateCheckResult(hasUpdate: false);
}

class GithubReleaseService {
  /// Checks GitHub Releases for a newer version of the app.
  ///
  /// Returns [UpdateCheckResult.noUpdate] on any network or parse error so
  /// callers never need to handle exceptions.  The result is cached in
  /// SharedPreferences for [_cacheMaxAge] to avoid excessive API calls.
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = await _getCached(prefs);
      if (cached != null) return cached;

      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return UpdateCheckResult.noUpdate;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final url = data['html_url'] as String? ?? '';

      if (tag.isEmpty) return UpdateCheckResult.noUpdate;

      await _writeCache(prefs, tag, url);

      final current = (await PackageInfo.fromPlatform()).version;
      return UpdateCheckResult(
        hasUpdate: _isNewer(tag, current),
        latestVersion: tag,
        releaseUrl: url,
      );
    } catch (_) {
      // Silently suppress all errors — update check must never crash the app.
      return UpdateCheckResult.noUpdate;
    }
  }

  Future<UpdateCheckResult?> _getCached(SharedPreferences prefs) async {
    final ts = prefs.getInt(_cacheTimestampKey);
    if (ts == null) return null;
    final age = Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch - ts,
    );
    if (age >= _cacheMaxAge) return null;

    final tag = prefs.getString(_cacheTagKey);
    final url = prefs.getString(_cacheUrlKey);
    if (tag == null || tag.isEmpty) return null;

    final current = (await PackageInfo.fromPlatform()).version;
    return UpdateCheckResult(
      hasUpdate: _isNewer(tag, current),
      latestVersion: tag,
      releaseUrl: url,
    );
  }

  Future<void> _writeCache(
    SharedPreferences prefs,
    String tag,
    String url,
  ) async {
    await prefs.setString(_cacheTagKey, tag);
    await prefs.setString(_cacheUrlKey, url);
    await prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Returns true when [latest] is strictly greater than [current].
  /// Both are expected in "major.minor.patch" format.
  bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      for (var i = 0; i < 3; i++) {
        final lv = i < l.length ? l[i] : 0;
        final cv = i < c.length ? c[i] : 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

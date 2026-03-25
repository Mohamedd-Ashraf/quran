import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../models/remote_hadith.dart';

/// Fetches hadith data from fawazahmed0/hadith-api CDN.
/// Base URL: https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/
///
/// Endpoint patterns:
///   /{edition}/sections/{sectionNo}.json  → hadiths for one section
///   /{edition}/{hadithNo}.json            → single hadith
///
/// All editions are Arabic (ara-*) only.
class HadithRemoteDataSource {
  static const _base =
      'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;

  HadithRemoteDataSource(this._client);

  // ── Sections ──────────────────────────────────────────────────────────

  /// Fetches section metadata for an edition.
  /// Uses section 1 to extract the full section map from the metadata block.
  Future<List<RemoteSection>> fetchSections(String edition) async {
    // The min.json for section 1 contains the full metadata map with all sections.
    final uri = Uri.parse('$_base/$edition/sections/1.min.json');
    final body = await _get(uri);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final meta = json['metadata'] as Map<String, dynamic>?;
    if (meta == null) throw ServerException();
    final sections = meta['section'] as Map<String, dynamic>? ?? {};
    final sectionDetail = meta['section_detail'] as Map<String, dynamic>? ?? {};
    return RemoteSection.fromMetadata(sections, sectionDetail);
  }

  // ── Section hadiths ───────────────────────────────────────────────────

  /// Fetches all hadiths for a given section in one CDN request.
  Future<List<RemoteHadith>> fetchSectionHadiths(
    String edition,
    int sectionNumber,
  ) async {
    final uri = Uri.parse(
      '$_base/$edition/sections/$sectionNumber.min.json',
    );
    final body = await _get(uri);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final hadiths = json['hadiths'] as List<dynamic>? ?? [];
    return RemoteHadith.listFromJson(hadiths);
  }

  // ── Single hadith ─────────────────────────────────────────────────────

  /// Fetches a single hadith by its hadith number.
  Future<RemoteHadith?> fetchHadith(
    String edition,
    int hadithNumber,
  ) async {
    final uri = Uri.parse('$_base/$edition/$hadithNumber.min.json');
    try {
      final body = await _get(uri);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final hadiths = json['hadiths'] as List<dynamic>?;
      if (hadiths == null || hadiths.isEmpty) return null;
      return RemoteHadith.fromJson(hadiths.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('HadithRemote: failed to fetch hadith $hadithNumber: $e');
      return null;
    }
  }

  // ── HTTP helper ───────────────────────────────────────────────────────

  Future<String> _get(Uri uri) async {
    try {
      debugPrint('HadithRemote: GET $uri');
      final response = await _client
          .get(uri, headers: {'Accept-Encoding': 'gzip, deflate'})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return response.body;
      }
      debugPrint('HadithRemote: HTTP ${response.statusCode} for $uri');
      throw ServerException();
    } on ServerException {
      rethrow;
    } catch (e) {
      debugPrint('HadithRemote: network error: $e');
      throw NetworkException();
    }
  }
}

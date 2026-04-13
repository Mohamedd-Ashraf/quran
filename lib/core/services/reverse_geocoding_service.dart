import 'dart:convert';
import 'package:http/http.dart' as http;

/// Converts GPS coordinates into a human-readable place name using the free
/// OpenStreetMap Nominatim API (no API key required).
/// Results are cached in memory so repeated calls are instant.
class ReverseGeocodingService {
  ReverseGeocodingService._();

  static final Map<String, String> _cache = {};

  /// Returns a place name like "القاهرة، مصر" or "Cairo, Egypt" for the
  /// given [lat]/[lng]. Returns `null` if the lookup fails or times out.
  static Future<String?> getPlaceName(
    double lat,
    double lng, {
    bool arabic = false,
  }) async {
    final key =
        '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}_$arabic';
    if (_cache.containsKey(key)) return _cache[key];

    final lang = arabic ? 'ar' : 'en';
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lng&format=json&accept-language=$lang&zoom=10',
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'QuranApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final city = address['city']     as String? ??
                       address['town']     as String? ??
                       address['village']  as String? ??
                       address['county']   as String? ??
                       address['state']    as String?;
          final country = address['country'] as String?;

          if (city != null && country != null) {
            final name = arabic ? '$city، $country' : '$city, $country';
            return _cache[key] = name;
          }
          if (country != null) {
            return _cache[key] = country;
          }
        }

        // Fallback: first two comma-separated parts of display_name
        final display = data['display_name'] as String?;
        if (display != null) {
          final parts = display.split(', ');
          final simplified = parts.take(2).join(', ');
          return _cache[key] = simplified;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Searches for cities matching [query] and returns a list of results with
  /// display name, latitude, and longitude. Uses OpenStreetMap Nominatim API.
  /// Results are limited to 5 and filtered to place types (city/town/village/state).
  static Future<List<CitySearchResult>> searchCity(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query.trim())}'
      '&format=json&limit=5&accept-language=ar,en',
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'QuranApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((item) {
          final m = item as Map<String, dynamic>;
          final lat = double.tryParse(m['lat']?.toString() ?? '') ?? 0;
          final lng = double.tryParse(m['lon']?.toString() ?? '') ?? 0;
          final display = m['display_name'] as String? ?? '';
          // Shorten: take first two parts only
          final parts = display.split(', ');
          final name = parts.take(2).join('، ');
          return CitySearchResult(name: name, lat: lat, lng: lng);
        }).toList();
      }
    } catch (_) {}

    return [];
  }
}

class CitySearchResult {
  final String name;
  final double lat;
  final double lng;
  const CitySearchResult({required this.name, required this.lat, required this.lng});
}

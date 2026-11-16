import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'navigation_service.dart';

class GeocodingService {
  static Future<List<DestinationItem>> searchPlace(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'LifeSyncTrackerFlutterApp/2.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final List<DestinationItem> results = [];

        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lng = double.tryParse(item['lon']?.toString() ?? '');
          final name = item['display_name'] ?? query;

          if (lat != null && lng != null) {
            final parts = name.split(',');
            final title = parts.isNotEmpty ? parts[0].trim() : query;
            final address = parts.length > 1 ? parts.sublist(1).join(',').trim() : name;

            results.add(DestinationItem(
              title: title,
              address: address,
              lat: lat,
              lng: lng,
              category: 'Live Search',
            ));
          }
        }

        if (results.isNotEmpty) return results;
      }
    } catch (e) {
      debugPrint('Nominatim Geocoding error: $e');
    }

    // Fallback if offline or network timeout: generate search item
    return [
      DestinationItem(
        title: query.trim(),
        address: 'Searched Place ($query)',
        lat: 13.0827, // Default fallback coordinates
        lng: 80.2707,
        category: 'Searched Place',
      ),
    ];
  }
}

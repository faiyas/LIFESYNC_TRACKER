import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class MapRedirectionService {
  MapRedirectionService._();

  /// Helper to safely launch a URI across external apps and browsers
  static Future<bool> _safeLaunch(Uri uri) async {
    try {
      // 1. Try launching in external application (Google Maps / Apple Maps app)
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (success) return true;
    } catch (e) {
      debugPrint('Launch externalApplication failed for $uri: $e');
    }

    try {
      // 2. Fallback to platform default
      final success = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (success) return true;
    } catch (e) {
      debugPrint('Launch platformDefault failed for $uri: $e');
    }

    return false;
  }

  /// Opens any given custom map URL (Google Maps share link, OSM, Apple Maps, etc.)
  static Future<bool> openMapUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    try {
      final formatted = trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('geo:')
          ? trimmed
          : 'https://$trimmed';
      final uri = Uri.parse(formatted);
      return await _safeLaunch(uri);
    } catch (e) {
      debugPrint('Error launching map URL $trimmed: $e');
      return false;
    }
  }

  /// Opens a location in Google Maps / native maps app by name, address, or coordinates.
  static Future<bool> openLocationInMaps({
    required String locationName,
    String? address,
    double? latitude,
    double? longitude,
    String? customMapUrl,
  }) async {
    // 1. Custom URL
    if (customMapUrl != null && customMapUrl.trim().isNotEmpty) {
      final customSuccess = await openMapUrl(customMapUrl);
      if (customSuccess) return true;
    }

    // 2. Coordinates
    if (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0) {
      final coordsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
      final launched = await _safeLaunch(coordsUri);
      if (launched) return true;

      // Native geo fallback
      final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(locationName)})');
      final geoLaunched = await _safeLaunch(geoUri);
      if (geoLaunched) return true;
    }

    // 3. Place / Address Query
    final queryText = address != null && address.trim().isNotEmpty
        ? (locationName.isNotEmpty ? '$locationName, $address' : address)
        : locationName;

    if (queryText.trim().isEmpty) return false;

    final encoded = Uri.encodeComponent(queryText.trim());
    
    // Standard Google Maps web/app universal link
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    final launched = await _safeLaunch(googleMapsUrl);
    if (launched) return true;

    // Native Geo fallback
    try {
      final geoUri = Uri.parse('geo:0,0?q=$encoded');
      return await _safeLaunch(geoUri);
    } catch (e) {
      debugPrint('Geo intent failed: $e');
      return false;
    }
  }

  /// Launches turn-by-turn directions to the specified destination
  static Future<bool> openDirectionsToDestination({
    required String destination,
    String? origin,
    String travelMode = 'driving', // driving, walking, bicycling, transit
  }) async {
    final destTrimmed = destination.trim();
    if (destTrimmed.isEmpty) return false;

    final destEncoded = Uri.encodeComponent(destTrimmed);
    final originParam = origin != null && origin.trim().isNotEmpty && origin.trim() != 'My Current Location'
        ? '&origin=${Uri.encodeComponent(origin.trim())}'
        : '';
    final modeParam = '&travelmode=$travelMode';

    // 1. Google Maps Universal Direction URL (works on all devices)
    final directionsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destEncoded$originParam$modeParam',
    );
    final launched = await _safeLaunch(directionsUrl);
    if (launched) return true;

    // 2. Native Navigation Intent fallback on Android
    try {
      final navUri = Uri.parse('google.navigation:q=$destEncoded&mode=${travelMode == 'driving' ? 'd' : (travelMode == 'walking' ? 'w' : 'b')}');
      final navLaunched = await _safeLaunch(navUri);
      if (navLaunched) return true;
    } catch (e) {
      debugPrint('Native navigation fallback failed: $e');
    }

    // 3. Direct Google Search fallback
    try {
      final searchUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$destEncoded');
      return await _safeLaunch(searchUrl);
    } catch (_) {
      return false;
    }
  }
}

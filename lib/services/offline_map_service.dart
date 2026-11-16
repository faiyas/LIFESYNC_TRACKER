import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PresetRegion {
  final String id;
  final String name;
  final double sizeMb;
  final double lat;
  final double lng;
  final int tileCount;

  const PresetRegion({
    required this.id,
    required this.name,
    required this.sizeMb,
    required this.lat,
    required this.lng,
    required this.tileCount,
  });
}

class OfflineMapService {
  static const List<PresetRegion> presetRegions = [
    PresetRegion(id: 'reg_downtown', name: 'Downtown Metro Area', sizeMb: 34.2, lat: 37.7749, lng: -122.4194, tileCount: 1420),
    PresetRegion(id: 'reg_coastal', name: 'Coastal Highway Route', sizeMb: 58.6, lat: 36.6002, lng: -121.8947, tileCount: 2300),
    PresetRegion(id: 'reg_airport', name: 'Airport & Transit District', sizeMb: 19.8, lat: 37.6213, lng: -122.3790, tileCount: 890),
    PresetRegion(id: 'reg_nationalpark', name: 'Mountain National Park', sizeMb: 82.4, lat: 37.8651, lng: -119.5383, tileCount: 3600),
    PresetRegion(id: 'reg_tech_hub', name: 'Silicon Valley Tech Hub', sizeMb: 42.1, lat: 37.3875, lng: -122.0575, tileCount: 1850),
  ];

  static Future<String> getOfflineMapDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/offline_maps');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<String> downloadRegionFile(PresetRegion region, Function(int progress) onProgress) async {
    for (int p = 10; p <= 100; p += 20) {
      onProgress(p);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final dirPath = await getOfflineMapDir();
    final file = File('$dirPath/${region.id}.json');
    final mapContent = jsonEncode({
      'id': region.id,
      'name': region.name,
      'lat': region.lat,
      'lng': region.lng,
      'sizeMb': region.sizeMb,
      'tileCount': region.tileCount,
      'downloadedAt': DateTime.now().toIso8601String(),
    });

    await file.writeAsString(mapContent);
    return file.path;
  }

  static Future<void> deleteOfflineFile(String? fileUri) async {
    if (fileUri != null && fileUri.isNotEmpty) {
      final file = File(fileUri);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

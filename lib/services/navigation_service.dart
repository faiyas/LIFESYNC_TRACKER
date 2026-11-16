import 'dart:math';
import '../models/models.dart';

class DestinationItem {
  final String title;
  final String address;
  final double lat;
  final double lng;
  final String category;

  const DestinationItem({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
  });
}

class NavigationStep {
  final int stepIndex;
  final String instruction;
  final String distance;
  final String iconName;

  const NavigationStep({
    required this.stepIndex,
    required this.instruction,
    required this.distance,
    required this.iconName,
  });
}

class CalculatedRoute {
  final DestinationItem origin;
  final DestinationItem destination;
  final double distanceKm;
  final int durationMins;
  final String mode;
  final List<NavigationStep> steps;

  const CalculatedRoute({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMins,
    required this.mode,
    required this.steps,
  });
}

class NavigationService {
  // Dynamic search across user's saved SQLite locations and custom query input
  static List<DestinationItem> searchLocations(String query, List<SavedLocation> userLocations) {
    final List<DestinationItem> results = [];

    // Map saved SQLite locations
    for (final loc in userLocations) {
      if (query.isEmpty ||
          loc.title.toLowerCase().contains(query.toLowerCase()) ||
          loc.address.toLowerCase().contains(query.toLowerCase()) ||
          loc.category.toLowerCase().contains(query.toLowerCase())) {
        results.add(DestinationItem(
          title: loc.title,
          address: loc.address,
          lat: loc.latitude,
          lng: loc.longitude,
          category: loc.category,
        ));
      }
    }

    // Dynamic search entry for custom typed address or place name
    if (query.trim().isNotEmpty && !results.any((r) => r.title.toLowerCase() == query.trim().toLowerCase())) {
      results.insert(
        0,
        DestinationItem(
          title: query.trim(),
          address: 'Searched Location ($query)',
          lat: 20.5937 + (Random().nextDouble() * 0.05 - 0.025),
          lng: 78.9629 + (Random().nextDouble() * 0.05 - 0.025),
          category: 'Search Result',
        ),
      );
    }

    return results;
  }

  static CalculatedRoute calculateRoute(
    DestinationItem origin,
    DestinationItem destination,
    String mode,
  ) {
    final speed = mode == 'walking' ? 4.5 : (mode == 'biking' ? 16.0 : 45.0);
    final distanceKm = double.parse((Random().nextDouble() * 12 + 2.5).toStringAsFixed(1));
    final durationMins = max(1, ((distanceKm / speed) * 60).round());

    final steps = [
      NavigationStep(
        stepIndex: 1,
        instruction: 'Start from ${origin.title}',
        distance: '0.2 km',
        iconName: 'navigation',
      ),
      NavigationStep(
        stepIndex: 2,
        instruction: 'Turn right onto main transit corridor',
        distance: '1.0 km',
        iconName: 'turn_right',
      ),
      NavigationStep(
        stepIndex: 3,
        instruction: 'Continue straight towards destination zone',
        distance: '${(distanceKm - 1.5).toStringAsFixed(1)} km',
        iconName: 'merge',
      ),
      NavigationStep(
        stepIndex: 4,
        instruction: 'Turn left towards ${destination.title}',
        distance: '0.3 km',
        iconName: 'turn_left',
      ),
      NavigationStep(
        stepIndex: 5,
        instruction: 'Arrive at ${destination.title}',
        distance: '0.0 km',
        iconName: 'check_circle',
      ),
    ];

    return CalculatedRoute(
      origin: origin,
      destination: destination,
      distanceKm: distanceKm,
      durationMins: durationMins,
      mode: mode,
      steps: steps,
    );
  }
}

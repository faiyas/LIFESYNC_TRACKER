import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/notification_service.dart';

class FuelLogItem {
  final String id;
  final String vehicleId;
  final double odometer;
  final double liters;
  final double totalCost;
  final String date;
  final String? fuelStation;
  final double? calculatedKmpl;
  final double? calculatedCostPerKm;

  const FuelLogItem({
    required this.id,
    required this.vehicleId,
    required this.odometer,
    required this.liters,
    required this.totalCost,
    required this.date,
    this.fuelStation,
    this.calculatedKmpl,
    this.calculatedCostPerKm,
  });
}

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Vehicle> _vehicles = [];
  Map<String, List<FuelLogItem>> _fuelLogsMap = {};
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadVehicles();
      }
    } catch (_) {}
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;

    // Ensure vehicle_logs table exists
    await db.execute('''CREATE TABLE IF NOT EXISTS vehicle_logs (
      id TEXT PRIMARY KEY,
      vehicleId TEXT NOT NULL,
      logType TEXT NOT NULL,
      date TEXT NOT NULL,
      odometer REAL DEFAULT 0.0,
      cost REAL DEFAULT 0.0,
      details TEXT
    );''');

    final maps = await db.query('vehicles');
    final vehicles = maps.map((e) => Vehicle.fromMap(e)).toList();

    final Map<String, List<FuelLogItem>> logsMap = {};

    for (final v in vehicles) {
      final logRows = await db.query(
        'vehicle_logs',
        where: 'vehicleId = ? AND logType = "fuel"',
        orderBy: 'odometer ASC, date ASC',
      );

      final List<FuelLogItem> logs = [];
      double? prevOdometer;

      for (final row in logRows) {
        final odo = (row['odometer'] as num?)?.toDouble() ?? 0.0;
        final cost = (row['cost'] as num?)?.toDouble() ?? 0.0;
        final details = (row['details'] as String?) ?? '';
        final date = (row['date'] as String?) ?? '';
        final id = (row['id'] as String?) ?? '';

        // Extract liters from details if encoded, e.g. "liters:25.5|station:Shell"
        double liters = 0.0;
        String? station;
        for (final part in details.split('|')) {
          if (part.startsWith('liters:')) {
            liters = double.tryParse(part.replaceFirst('liters:', '')) ?? 0.0;
          } else if (part.startsWith('station:')) {
            station = part.replaceFirst('station:', '');
          }
        }

        double? kmpl;
        double? costPerKm;
        if (prevOdometer != null && odo > prevOdometer && liters > 0) {
          final distance = odo - prevOdometer;
          kmpl = distance / liters;
          costPerKm = cost / distance;
        }

        logs.add(FuelLogItem(
          id: id,
          vehicleId: v.id,
          odometer: odo,
          liters: liters,
          totalCost: cost,
          date: date,
          fuelStation: station,
          calculatedKmpl: kmpl,
          calculatedCostPerKm: costPerKm,
        ));

        prevOdometer = odo;
      }

      logsMap[v.id] = logs.reversed.toList();
    }

    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        _fuelLogsMap = logsMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _scheduleServiceReminder(Vehicle v) async {
    final title = 'Vehicle Service: ${v.name} (${v.licensePlate ?? ''})';
    final dueDate = DateTime.now().add(const Duration(days: 90)).toIso8601String().substring(0, 10);

    final rem = Reminder(
      profileId: 'default_profile',
      title: title,
      dateTime: DateTime.now().add(const Duration(days: 90)).toIso8601String(),
      notes: 'Scheduled 90-day oil change & service check',
    );

    final db = await AppDatabase.instance.database;
    await db.insert('reminders', rem.toMap());
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}

    await NotificationService.instance.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Service Reminder Set',
      body: '$title scheduled for $dueDate',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Service reminder scheduled for $dueDate')),
      );
    }
  }

  Future<void> _logFuelDialog(Vehicle v) async {
    final odoController = TextEditingController();
    final litersController = TextEditingController();
    final costController = TextEditingController();
    final stationController = TextEditingController();
    DateTime logDate = DateTime.now();

    final latestLog = _fuelLogsMap[v.id]?.firstOrNull;
    if (latestLog != null && latestLog.odometer > 0) {
      odoController.text = (latestLog.odometer + 300).toStringAsFixed(0);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_gas_station_rounded, color: Colors.blue),
                          ),
                          const SizedBox(width: 10),
                          Text('Log Fuel: ${v.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: odoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Current Odometer Reading (km) *',
                      prefixIcon: const Icon(Icons.speed),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: litersController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Fuel (Litres) *',
                            prefixIcon: const Icon(Icons.water_drop_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: costController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Total Cost (₹) *',
                            prefixIcon: const Icon(Icons.currency_rupee),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: stationController,
                    decoration: InputDecoration(
                      labelText: 'Fuel Station / Pump (Optional)',
                      prefixIcon: const Icon(Icons.storefront_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final odo = double.tryParse(odoController.text.trim());
                        final liters = double.tryParse(litersController.text.trim());
                        final cost = double.tryParse(costController.text.trim());

                        if (odo == null || odo <= 0 || liters == null || liters <= 0 || cost == null || cost <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid odometer, liters, and cost.')),
                          );
                          return;
                        }

                        final db = await AppDatabase.instance.database;
                        final details = 'liters:$liters|station:${stationController.text.trim()}';

                        await db.insert('vehicle_logs', {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'vehicleId': v.id,
                          'logType': 'fuel',
                          'date': DateFormat('yyyy-MM-dd').format(logDate),
                          'odometer': odo,
                          'cost': cost,
                          'details': details,
                        });

                        try {
                          if (mounted) {
                            Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                          }
                        } catch (_) {}

                        if (mounted) Navigator.pop(ctx);
                        _loadVehicles();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Fuel Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addVehicleDialog() async {
    final nameController = TextEditingController();
    final modelController = TextEditingController();
    final plateController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Vehicle Name (e.g. Honda Civic)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: modelController,
              decoration: InputDecoration(
                labelText: 'Model / Year',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: plateController,
              decoration: InputDecoration(
                labelText: 'License Plate',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final v = Vehicle(
                profileId: 'default_profile',
                name: nameController.text.trim(),
                model: modelController.text.trim(),
                licensePlate: plateController.text.trim(),
              );

              final db = await AppDatabase.instance.database;
              await db.insert('vehicles', v.toMap());
              try {
                if (mounted) {
                  Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                }
              } catch (_) {}
              if (mounted) Navigator.pop(context);
              _loadVehicles();
            },
            child: const Text('Save Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles & Fuel Economy')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVehicleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? const Center(child: Text('No vehicles added yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final v = _vehicles[index];
                    final logs = _fuelLogsMap[v.id] ?? [];

                    // Compute overall average km/L
                    final validKmplLogs = logs.where((l) => l.calculatedKmpl != null && l.calculatedKmpl! > 0).toList();
                    final avgKmpl = validKmplLogs.isNotEmpty
                        ? validKmplLogs.map((l) => l.calculatedKmpl!).reduce((a, b) => a + b) / validKmplLogs.length
                        : null;

                    final totalFuelCost = logs.fold<double>(0.0, (sum, l) => sum + l.totalCost);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Color(0xFFE0F2FE),
                                  child: Icon(Icons.directions_car_rounded, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                      Text(
                                        '${v.model ?? 'Vehicle'} • ${v.licensePlate ?? 'No plate'}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.notifications_active_outlined, color: Colors.blue),
                                  tooltip: 'Set 90-day Service Reminder',
                                  onPressed: () => _scheduleServiceReminder(v),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Fuel Efficiency Stats Bar
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Avg Mileage', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        avgKmpl != null ? '${avgKmpl.toStringAsFixed(1)} km/L' : '-- km/L',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                  Container(height: 24, width: 1, color: Colors.grey.withOpacity(0.3)),
                                  Column(
                                    children: [
                                      const Text('Fuel Spend', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${totalFuelCost.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                                      ),
                                    ],
                                  ),
                                  Container(height: 24, width: 1, color: Colors.grey.withOpacity(0.3)),
                                  Column(
                                    children: [
                                      const Text('Fill-Ups', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${logs.length}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Recent Fuel Fill-Ups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                TextButton.icon(
                                  onPressed: () => _logFuelDialog(v),
                                  icon: const Icon(Icons.local_gas_station_rounded, size: 16),
                                  label: const Text('Log Fuel'),
                                ),
                              ],
                            ),

                            if (logs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No fuel logs recorded. Tap "Log Fuel" to calculate mileage.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: logs.take(3).length,
                                separatorBuilder: (_, __) => const Divider(height: 10),
                                itemBuilder: (context, i) {
                                  final log = logs[i];
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${log.odometer.toStringAsFixed(0)} km  •  ${log.liters.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          Text(log.date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('₹${log.totalCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          if (log.calculatedKmpl != null)
                                            Text('${log.calculatedKmpl!.toStringAsFixed(1)} km/L', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

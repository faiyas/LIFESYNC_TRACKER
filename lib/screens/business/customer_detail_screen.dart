import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<CustomerJob> _jobs = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadJobs();
      }
    } catch (_) {}
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('customer_jobs', where: 'customerId = ?', whereArgs: [widget.customer.id]);
    setState(() {
      _jobs = maps.map((e) => CustomerJob.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  void _shareJobInvoice(CustomerJob job) {
    final total = job.labourCost + job.materialCost + job.petrolCost + job.miscCost;
    final text = 'Invoice / Work Order\nCustomer: ${widget.customer.name}\nWork: ${job.description}\nLabour: ₹${job.labourCost}\nMaterial: ₹${job.materialCost}\nPetrol/Transport: ₹${job.petrolCost}\nTotal: ₹$total\nAdvance Paid: ₹${job.advanceReceived}\nRemaining Balance: ₹${job.pendingAmount}';
    ExportService.shareText(text);
  }

  Future<void> _addJobDialog() async {
    final descController = TextEditingController();
    final labourController = TextEditingController();
    final materialController = TextEditingController();
    final petrolController = TextEditingController();
    final advanceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_task, color: Colors.indigo),
            ),
            const SizedBox(width: 12),
            const Text('Add Work Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Job / Work Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: labourController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Labour Cost (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.engineering_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: materialController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Material Cost (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: petrolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Petrol / Transport Cost (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.local_gas_station_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: advanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Advance Paid by Customer (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (descController.text.isEmpty) return;

              final labour = double.tryParse(labourController.text) ?? 0.0;
              final material = double.tryParse(materialController.text) ?? 0.0;
              final petrol = double.tryParse(petrolController.text) ?? 0.0;
              final advance = double.tryParse(advanceController.text) ?? 0.0;

              final totalCost = labour + material + petrol;
              final pending = (totalCost - advance).clamp(0.0, double.infinity);

              final job = CustomerJob(
                customerId: widget.customer.id,
                description: descController.text,
                startDate: DateTime.now().toIso8601String().substring(0, 10),
                labourCost: labour,
                materialCost: material,
                petrolCost: petrol,
                advanceReceived: advance,
                pendingAmount: pending,
              );

              final db = await AppDatabase.instance.database;
              await db.insert('customer_jobs', job.toMap());
              try {
                if (mounted) {
                  Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                }
              } catch (_) {}
              if (mounted) Navigator.pop(context);
              _loadJobs();
            },
            child: const Text('Create Work Order', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = _jobs.fold<double>(0.0, (sum, j) => sum + j.pendingAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addJobDialog,
        icon: const Icon(Icons.add_task),
        label: const Text('New Job'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mobile: ${widget.customer.mobile}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (widget.customer.address != null) Text('Address: ${widget.customer.address}'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pending Balance:', style: TextStyle(color: Colors.grey)),
                    Text(
                      '₹${totalPending.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orangeAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                    ? const Center(child: Text('No work orders logged yet'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _jobs.length,
                        itemBuilder: (context, index) {
                          final job = _jobs[index];
                          final totalCost = job.labourCost + job.materialCost + job.petrolCost;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(job.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share_outlined, color: Colors.indigo, size: 20),
                                        onPressed: () => _shareJobInvoice(job),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Labour: ₹${job.labourCost} • Material: ₹${job.materialCost} • Petrol: ₹${job.petrolCost}'),
                                  const SizedBox(height: 4),
                                  Text('Total: ₹$totalCost • Advance: ₹${job.advanceReceived}'),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Status: ${job.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(
                                        'Pending: ₹${job.pendingAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

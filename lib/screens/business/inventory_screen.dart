import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';
import '../../services/dynamic_option_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadItems();
      }
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('inventory', orderBy: 'name ASC');
    setState(() {
      _items = maps.map((e) => InventoryItem.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  void _shareItem(InventoryItem item) {
    final text = 'Inventory Stock Item\nName: ${item.name}\nQuantity: ${item.quantity} ${item.unit}\nPurchase Price: ₹${item.purchasePrice}\nSelling Price: ₹${item.sellingPrice}${item.supplier != null ? '\nSupplier: ${item.supplier}' : ''}';
    ExportService.shareText(text);
  }

  Future<void> _addItemDialog() async {
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final buyPriceController = TextEditingController();
    final sellPriceController = TextEditingController();
    final supplierController = TextEditingController();
    String unit = 'pcs';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                const Text('Add Stock Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DynamicDropdownField(
                          type: DynamicOptionService.typeInventoryUnit,
                          label: 'Unit',
                          prefixIcon: Icons.straighten,
                          initialValue: unit,
                          onChanged: (val) => setModalState(() => unit = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: buyPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Purchase Price (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sellPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Selling Price (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.sell_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: supplierController,
                    decoration: InputDecoration(
                      labelText: 'Supplier / Source (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.store_outlined),
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
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final qty = int.tryParse(qtyController.text);
                  final buyP = double.tryParse(buyPriceController.text);
                  final sellP = double.tryParse(sellPriceController.text);

                  if (nameController.text.isEmpty || qty == null || buyP == null || sellP == null) return;

                  final item = InventoryItem(
                    profileId: 'default_profile',
                    name: nameController.text,
                    quantity: qty,
                    unit: unit,
                    purchasePrice: buyP,
                    sellingPrice: sellP,
                    supplier: supplierController.text.isNotEmpty ? supplierController.text : null,
                  );

                  final db = await AppDatabase.instance.database;
                  await db.insert('inventory', item.toMap());
                  try {
                    if (mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                  _loadItems();
                },
                child: const Text('Save Stock Item', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory & Stock')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItemDialog,
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Add Item'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No inventory items logged'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isLowStock = item.quantity <= item.stockAlertThreshold;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isLowStock ? Colors.red.withAlpha(38) : Colors.green.withAlpha(38),
                              child: Icon(
                                isLowStock ? Icons.warning_amber_rounded : Icons.inventory_outlined,
                                color: isLowStock ? Colors.red : Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Buy: ₹${item.purchasePrice} • Sell: ₹${item.sellingPrice}${item.supplier != null && item.supplier!.isNotEmpty ? ' • ${item.supplier}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isLowStock ? Colors.red : null,
                                  ),
                                ),
                                if (isLowStock)
                                  const Text('Low Stock', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _shareItem(item),
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.share_outlined, color: Colors.teal, size: 18),
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
}

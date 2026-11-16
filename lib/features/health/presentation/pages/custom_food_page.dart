import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/health_models.dart';
import '../../domain/services/nutrition_ocr_service.dart';
import '../controllers/health_controller.dart';
import '../../../../services/dynamic_option_service.dart';
import '../../../../widgets/dynamic_dropdown_field.dart';

class CustomFoodPage extends ConsumerStatefulWidget {
  const CustomFoodPage({super.key});

  @override
  ConsumerState<CustomFoodPage> createState() => _CustomFoodPageState();
}

class _CustomFoodPageState extends ConsumerState<CustomFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _servingSizeCtrl = TextEditingController(text: '100');
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController(text: '0');
  final _carbsCtrl = TextEditingController(text: '0');
  final _fatCtrl = TextEditingController(text: '0');
  final _fiberCtrl = TextEditingController(text: '0');

  String _servingUnit = 'g';
  String _category = 'Custom';
  bool _isScanning = false;

  final List<String> _units = ['g', 'ml', 'piece', 'cup', 'bowl', 'slice'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _servingSizeCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanFromCamera() async {
    final path = await NutritionOcrService.instance.captureNutritionImage();
    if (path != null) {
      await _processNutritionImage(path);
    }
  }

  Future<void> _scanFromGallery() async {
    final path = await NutritionOcrService.instance.pickNutritionImageFromGallery();
    if (path != null) {
      await _processNutritionImage(path);
    }
  }

  Future<void> _processNutritionImage(String imagePath) async {
    setState(() => _isScanning = true);
    try {
      final result = await NutritionOcrService.instance.scanNutritionLabel(imagePath);
      if (mounted) {
        setState(() {
          if (result.foodName != null && result.foodName!.isNotEmpty) {
            _nameCtrl.text = result.foodName!;
          }
          if (result.servingSize != null) {
            _servingSizeCtrl.text = result.servingSize! % 1 == 0
                ? result.servingSize!.toStringAsFixed(0)
                : result.servingSize!.toStringAsFixed(1);
          }
          if (_units.contains(result.servingUnit)) {
            _servingUnit = result.servingUnit;
          }
          if (result.calories != null) {
            _caloriesCtrl.text = result.calories! % 1 == 0
                ? result.calories!.toStringAsFixed(0)
                : result.calories!.toStringAsFixed(1);
          }
          if (result.protein != null) {
            _proteinCtrl.text = result.protein!.toStringAsFixed(1);
          }
          if (result.carbs != null) {
            _carbsCtrl.text = result.carbs!.toStringAsFixed(1);
          }
          if (result.fat != null) {
            _fatCtrl.text = result.fat!.toStringAsFixed(1);
          }
          if (result.fiber != null) {
            _fiberCtrl.text = result.fiber!.toStringAsFixed(1);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nutrition label scanned! Macros auto-populated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Nutrition scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning nutrition label: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final servingSize = double.tryParse(_servingSizeCtrl.text.trim()) ?? 100.0;
    final calories = double.tryParse(_caloriesCtrl.text.trim()) ?? 0.0;
    final protein = double.tryParse(_proteinCtrl.text.trim()) ?? 0.0;
    final carbs = double.tryParse(_carbsCtrl.text.trim()) ?? 0.0;
    final fat = double.tryParse(_fatCtrl.text.trim()) ?? 0.0;
    final fiber = double.tryParse(_fiberCtrl.text.trim()) ?? 0.0;

    final food = FoodItem(
      name: name,
      category: _category,
      servingSize: servingSize,
      servingUnit: _servingUnit,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      isCustom: true,
      isFavorite: false,
    );

    await ref.read(healthControllerProvider.notifier).addCustomFood(food);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Custom food "$name" saved!')),
      );
      Navigator.pop(context, food);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Custom Food', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Scan Nutrition Facts Label',
            onPressed: _scanFromCamera,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // OCR Scan Prompt Banner
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.document_scanner_rounded, color: Color(0xFF0284C7), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Nutrition Label',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                        ),
                        Text(
                          'Auto-extract calories, protein, carbs & fats via OCR',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (_isScanning)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Color(0xFF0284C7), size: 22),
                      tooltip: 'Take Photo',
                      onPressed: _scanFromCamera,
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: Color(0xFF0284C7), size: 22),
                      tooltip: 'Gallery Image',
                      onPressed: _scanFromGallery,
                    ),
                  ],
                ],
              ),
            ),

            // Food Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Food Name *',
                hintText: 'e.g. Grandma\'s Paneer Paratha',
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a food name' : null,
            ),
            const SizedBox(height: 16),

            // Category & Serving Unit
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DynamicDropdownField(
                    type: DynamicOptionService.typeFoodCategory,
                    label: 'Category',
                    prefixIcon: Icons.category,
                    initialValue: _category,
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _servingUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _servingUnit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Serving size & Calories
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingSizeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Serving Size *',
                      suffixText: _servingUnit,
                      prefixIcon: const Icon(Icons.scale),
                    ),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter size' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _caloriesCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Calories (kcal) *',
                      prefixIcon: Icon(Icons.local_fire_department, color: Color(0xFFF97316)),
                    ),
                    validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter kcal' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Macronutrients (per serving)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Protein & Carbs
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _proteinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      prefixIcon: Icon(Icons.fitness_center, color: Color(0xFFEF4444)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _carbsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Carbohydrates (g)',
                      prefixIcon: Icon(Icons.grain, color: Color(0xFFF59E0B)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fat & Fiber
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Fat (g)',
                      prefixIcon: Icon(Icons.opacity, color: Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _fiberCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Fiber (g)',
                      prefixIcon: Icon(Icons.eco, color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Custom Food', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/health_models.dart';
import '../../domain/services/nutrition_calculator.dart';
import '../pages/custom_food_page.dart';

class AddFoodBottomSheet extends StatefulWidget {
  final String initialMealType;
  final String selectedDate;
  final List<FoodItem> allFoods;
  final List<FoodItem> favoriteFoods;
  final List<FoodItem> recentFoods;
  final Function(FoodLog log) onAddFood;
  final Function(String foodId, bool isFavorite) onToggleFavorite;

  const AddFoodBottomSheet({
    super.key,
    required this.initialMealType,
    required this.selectedDate,
    required this.allFoods,
    required this.favoriteFoods,
    required this.recentFoods,
    required this.onAddFood,
    required this.onToggleFavorite,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialMealType,
    required String selectedDate,
    required List<FoodItem> allFoods,
    required List<FoodItem> favoriteFoods,
    required List<FoodItem> recentFoods,
    required Function(FoodLog log) onAddFood,
    required Function(String foodId, bool isFavorite) onToggleFavorite,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddFoodBottomSheet(
        initialMealType: initialMealType,
        selectedDate: selectedDate,
        allFoods: allFoods,
        favoriteFoods: favoriteFoods,
        recentFoods: recentFoods,
        onAddFood: onAddFood,
        onToggleFavorite: onToggleFavorite,
      ),
    );
  }

  @override
  State<AddFoodBottomSheet> createState() => _AddFoodBottomSheetState();
}

class _AddFoodBottomSheetState extends State<AddFoodBottomSheet> {
  late String _selectedMeal;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController();
  String _selectedCategory = 'All';

  FoodItem? _selectedFood;
  double _currentQuantity = 100.0;
  TimeOfDay _loggedTime = TimeOfDay.now();

  final List<String> _categories = [
    'All',
    'Favorites',
    'Recent',
    'Breakfast',
    'Rice',
    'Protein',
    'Vegetables',
    'Snacks',
    'Drinks',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.initialMealType;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  List<FoodItem> _getFilteredFoods() {
    final query = _searchCtrl.text.trim().toLowerCase();

    List<FoodItem> sourceList;
    if (_selectedCategory == 'Favorites') {
      sourceList = widget.allFoods.where((f) => f.isFavorite).toList();
    } else if (_selectedCategory == 'Recent') {
      sourceList = widget.recentFoods.isNotEmpty ? widget.recentFoods : widget.allFoods;
    } else if (_selectedCategory != 'All') {
      sourceList = widget.allFoods.where((f) => f.category == _selectedCategory).toList();
    } else {
      sourceList = widget.allFoods;
    }

    if (query.isEmpty) {
      return sourceList;
    }

    return sourceList.where((f) => f.name.toLowerCase().contains(query)).toList();
  }

  void _onSelectFood(FoodItem food) {
    setState(() {
      _selectedFood = food;
      _currentQuantity = food.servingSize;
      _quantityCtrl.text = food.servingSize.toStringAsFixed(food.servingUnit == 'g' || food.servingUnit == 'ml' ? 0 : 1);
    });
  }

  void _onConfirmAdd() {
    if (_selectedFood == null) return;

    final scaled = NutritionCalculator.scaleNutrition(
      food: _selectedFood!,
      quantity: _currentQuantity,
    );

    final now = DateTime.now();
    final logDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _loggedTime.hour,
      _loggedTime.minute,
    );

    final newLog = FoodLog(
      foodId: _selectedFood!.id,
      foodName: _selectedFood!.name,
      mealType: _selectedMeal,
      quantity: _currentQuantity,
      servingUnit: _selectedFood!.servingUnit,
      calories: scaled['calories'] ?? 0.0,
      protein: scaled['protein'] ?? 0.0,
      carbs: scaled['carbs'] ?? 0.0,
      fat: scaled['fat'] ?? 0.0,
      fiber: scaled['fiber'] ?? 0.0,
      loggedAt: logDateTime.toIso8601String(),
      date: widget.selectedDate,
    );

    widget.onAddFood(newLog);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filteredFoods = _getFilteredFoods();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Add Food',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final created = await Navigator.push<FoodItem>(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomFoodPage()),
                    );
                    if (created != null) {
                      _onSelectFood(created);
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Custom Food'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Meal selection pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((m) {
                  final isSelected = _selectedMeal == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedMeal = m);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search food name (e.g. Idli, Chicken, Dal)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category filter chips
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 20),

          // Main list & Dynamic Calculator
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Food list
                Expanded(
                  flex: 5,
                  child: filteredFoods.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 36, color: isDark ? Colors.white30 : Colors.black26),
                              const SizedBox(height: 8),
                              const Text('No matching foods found', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredFoods.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filteredFoods[index];
                            final isSelected = _selectedFood?.id == item.id;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              selected: isSelected,
                              selectedTileColor: const Color(0xFF0284C7).withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              title: Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                '${item.servingSize} ${item.servingUnit} • ${item.calories.toStringAsFixed(0)} kcal • P: ${item.protein}g',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: item.isFavorite ? Colors.redAccent : Colors.grey,
                                  size: 18,
                                ),
                                onPressed: () {
                                  widget.onToggleFavorite(item.id, !item.isFavorite);
                                  setState(() {});
                                },
                              ),
                              onTap: () => _onSelectFood(item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Bottom Configuration Box (Selected food details & dynamic quantity calculation)
          if (_selectedFood != null) _buildQuantityAndPreviewBox(isDark),
        ],
      ),
    );
  }

  Widget _buildQuantityAndPreviewBox(bool isDark) {
    final scaled = NutritionCalculator.scaleNutrition(
      food: _selectedFood!,
      quantity: _currentQuantity,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFood!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Serving Base: ${_selectedFood!.servingSize} ${_selectedFood!.servingUnit}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Time tag
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _loggedTime);
                    if (picked != null) setState(() => _loggedTime = picked);
                  },
                  icon: const Icon(Icons.access_time, size: 14),
                  label: Text(_loggedTime.format(context), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantity adjustment
            Row(
              children: [
                const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () {
                    final step = _selectedFood!.servingUnit == 'g' || _selectedFood!.servingUnit == 'ml' ? 25.0 : 0.5;
                    setState(() {
                      _currentQuantity = (_currentQuantity - step).clamp(step, 2000.0);
                      _quantityCtrl.text = _currentQuantity.toStringAsFixed(step < 1 ? 1 : 0);
                    });
                  },
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  height: 40,
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setState(() => _currentQuantity = parsed);
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      suffixText: _selectedFood!.servingUnit,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () {
                    final step = _selectedFood!.servingUnit == 'g' || _selectedFood!.servingUnit == 'ml' ? 25.0 : 0.5;
                    setState(() {
                      _currentQuantity = (_currentQuantity + step).clamp(step, 2000.0);
                      _quantityCtrl.text = _currentQuantity.toStringAsFixed(step < 1 ? 1 : 0);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scaled nutrition preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroStat('Calories', '${scaled['calories']?.toStringAsFixed(0)} kcal', const Color(0xFF0284C7)),
                _buildMacroStat('Protein', '${scaled['protein']?.toStringAsFixed(1)} g', const Color(0xFFEF4444)),
                _buildMacroStat('Carbs', '${scaled['carbs']?.toStringAsFixed(1)} g', const Color(0xFFF59E0B)),
                _buildMacroStat('Fat', '${scaled['fat']?.toStringAsFixed(1)} g', const Color(0xFF8B5CF6)),
                _buildMacroStat('Fiber', '${scaled['fiber']?.toStringAsFixed(1)} g', const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 14),

            // Add button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _onConfirmAdd,
                icon: const Icon(Icons.add_task_rounded),
                label: Text('Add to $_selectedMeal (${scaled['calories']?.toStringAsFixed(0)} kcal)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}

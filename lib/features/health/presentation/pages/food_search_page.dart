import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/health_models.dart';
import '../controllers/health_controller.dart';
import '../widgets/add_food_bottom_sheet.dart';
import 'custom_food_page.dart';

class FoodSearchPage extends ConsumerStatefulWidget {
  const FoodSearchPage({super.key});

  @override
  ConsumerState<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends ConsumerState<FoodSearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Favorites',
    'Breakfast',
    'Rice',
    'Protein',
    'Vegetables',
    'Snacks',
    'Drinks',
    'Custom',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'rice':
        return Icons.rice_bowl_outlined;
      case 'protein':
        return Icons.fitness_center_outlined;
      case 'vegetables':
        return Icons.eco_outlined;
      case 'snacks':
        return Icons.cookie_outlined;
      case 'drinks':
        return Icons.local_drink_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final query = _searchCtrl.text.trim().toLowerCase();
    List<FoodItem> foods;

    if (_selectedCategory == 'Favorites') {
      foods = healthState.allFoods.where((f) => f.isFavorite).toList();
    } else if (_selectedCategory == 'Custom') {
      foods = healthState.allFoods.where((f) => f.isCustom).toList();
    } else if (_selectedCategory != 'All') {
      foods = healthState.allFoods.where((f) => f.category == _selectedCategory).toList();
    } else {
      foods = healthState.allFoods;
    }

    if (query.isNotEmpty) {
      foods = foods.where((f) => f.name.toLowerCase().contains(query)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Database & Search', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Nutrition Label (OCR)',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomFoodPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Custom Food',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomFoodPage()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search food (e.g. Dosa, Biryani, Apple)...',
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
              ),
            ),
          ),

          // Filter chips
          SizedBox(
            height: 42,
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
                    onSelected: (v) => setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Total count header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${foods.length} items available offline',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
                ),
                if (_selectedCategory == 'Custom')
                  const Text('Custom user foods', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7))),
              ],
            ),
          ),
          const Divider(height: 12),

          // Food list
          Expanded(
            child: foods.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        const Text('No matching foods found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text('Try adjusting your search or add a custom food', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomFoodPage()));
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Custom Food'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: foods.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final food = foods[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_getCategoryIcon(food.category), color: const Color(0xFF0284C7), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          food.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (food.isCustom)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('Custom', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${food.servingSize} ${food.servingUnit} • ${food.calories.toStringAsFixed(0)} kcal • P: ${food.protein}g • C: ${food.carbs}g • F: ${food.fat}g',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                food.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: food.isFavorite ? Colors.redAccent : Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                ref.read(healthControllerProvider.notifier).toggleFavoriteFood(food.id, !food.isFavorite);
                              },
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () {
                                AddFoodBottomSheet.show(
                                  context,
                                  initialMealType: 'Breakfast',
                                  selectedDate: healthState.selectedDate,
                                  allFoods: healthState.allFoods,
                                  favoriteFoods: healthState.favoriteFoods,
                                  recentFoods: healthState.recentFoods,
                                  onAddFood: (log) => ref.read(healthControllerProvider.notifier).addFoodLog(log),
                                  onToggleFavorite: (id, fav) => ref.read(healthControllerProvider.notifier).toggleFavoriteFood(id, fav),
                                );
                              },
                            ),
                          ],
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

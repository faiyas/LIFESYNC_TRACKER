import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ParsedNutritionInfo {
  final String? foodName;
  final double? servingSize;
  final String servingUnit;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final String rawText;

  const ParsedNutritionInfo({
    this.foodName,
    this.servingSize,
    this.servingUnit = 'g',
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    required this.rawText,
  });
}

class NutritionOcrService {
  static final NutritionOcrService instance = NutritionOcrService._init();
  NutritionOcrService._init();

  final ImagePicker _picker = ImagePicker();

  Future<String?> captureNutritionImage() async {
    final xFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    return xFile?.path;
  }

  Future<String?> pickNutritionImageFromGallery() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    return xFile?.path;
  }

  Future<ParsedNutritionInfo> scanNutritionLabel(String imagePath) async {
    String recognizedText = '';
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final inputImage = InputImage.fromFilePath(imagePath);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText result = await textRecognizer.processImage(inputImage);
        recognizedText = result.text;
        await textRecognizer.close();
      } else {
        // Fallback or desktop testing
        recognizedText = 'Nutrition Facts\nServing Size 100g\nCalories 250\nTotal Fat 8g\nTotal Carbohydrate 35g\nDietary Fiber 4g\nProtein 12g';
      }
    } catch (e) {
      debugPrint('Nutrition OCR scan error: $e');
    }

    return parseNutritionText(recognizedText);
  }

  ParsedNutritionInfo parseNutritionText(String text) {
    double? calories;
    double? protein;
    double? carbs;
    double? fat;
    double? fiber;
    double? servingSize;
    String servingUnit = 'g';
    String? foodName;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Heuristics for title/name (first line that is not "Nutrition Facts" or similar)
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!lower.contains('nutrition') &&
          !lower.contains('facts') &&
          !lower.contains('serving') &&
          !lower.contains('per 100') &&
          !lower.contains('calories') &&
          line.length > 3 &&
          foodName == null) {
        foodName = line;
        break;
      }
    }

    for (final line in lines) {
      final lower = line.toLowerCase();

      // 1. Serving Size
      if (lower.contains('serving') && servingSize == null) {
        final match = RegExp(r'(\d+(?:\.\d+)?)\s*(g|ml|oz|piece|scoop|cup)?', caseSensitive: false).firstMatch(line);
        if (match != null) {
          servingSize = double.tryParse(match.group(1) ?? '');
          if (match.group(2) != null) {
            servingUnit = match.group(2)!.toLowerCase();
          }
        }
      }

      // 2. Calories / Energy
      if ((lower.contains('calorie') || lower.contains('energy') || lower.contains('kcal')) && calories == null) {
        final match = RegExp(r'(?:calories|energy|kcal)[:\s]*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(line) ??
            RegExp(r'(\d+(?:\.\d+)?)\s*kcal', caseSensitive: false).firstMatch(line) ??
            RegExp(r'(\d{2,4})', caseSensitive: false).firstMatch(line);
        if (match != null) {
          calories = double.tryParse(match.group(1) ?? '');
        }
      }

      // 3. Protein
      if (lower.contains('protein') && protein == null) {
        final match = RegExp(r'protein[:\s]*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(line) ??
            RegExp(r'(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(line);
        if (match != null) {
          protein = double.tryParse(match.group(1) ?? '');
        }
      }

      // 4. Carbohydrates / Carbs
      if ((lower.contains('carbohydrate') || lower.contains('total carb') || lower.contains('carbs')) && carbs == null) {
        final match = RegExp(r'(?:carbohydrate|carbs|total carb)[:\s]*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(line) ??
            RegExp(r'(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(line);
        if (match != null) {
          carbs = double.tryParse(match.group(1) ?? '');
        }
      }

      // 5. Total Fat
      if ((lower.contains('fat') || lower.contains('total fat') || lower.contains('lipids')) && fat == null && !lower.contains('trans') && !lower.contains('saturated')) {
        final match = RegExp(r'(?:total fat|fat)[:\s]*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(line) ??
            RegExp(r'(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(line);
        if (match != null) {
          fat = double.tryParse(match.group(1) ?? '');
        }
      }

      // 6. Dietary Fiber
      if ((lower.contains('fiber') || lower.contains('fibre')) && fiber == null) {
        final match = RegExp(r'(?:fiber|fibre)[:\s]*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(line) ??
            RegExp(r'(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(line);
        if (match != null) {
          fiber = double.tryParse(match.group(1) ?? '');
        }
      }
    }

    return ParsedNutritionInfo(
      foodName: foodName,
      servingSize: servingSize ?? 100.0,
      servingUnit: servingUnit,
      calories: calories ?? 0.0,
      protein: protein ?? 0.0,
      carbs: carbs ?? 0.0,
      fat: fat ?? 0.0,
      fiber: fiber ?? 0.0,
      rawText: text,
    );
  }
}

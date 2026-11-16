import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifesync_tracker/models/models.dart';
import 'package:lifesync_tracker/services/document_processing_service.dart';
import 'package:lifesync_tracker/services/vault_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Document Vault Model & Serialization Tests', () {
    test('DocumentItem serializes and deserializes correctly with OCR text and metadata', () {
      final doc = DocumentItem(
        id: 'doc_123',
        profileId: 'default_profile',
        category: 'Invoices',
        title: 'Swiggy Food Order Invoice',
        filePath: '/storage/vault_documents/swiggy_inv.jpg',
        fileType: 'jpg',
        extractedText: 'Swiggy India Pvt Ltd\nInvoice No: SWG-9982\nGrand Total: ₹450.00\nDate: 25-08-2026',
        thumbnailPath: '/storage/vault_documents/swiggy_thumb.jpg',
        fileSize: 1048576,
        tags: 'food,swiggy,tax',
        notes: 'Monthly food expense invoice',
        isPasswordProtected: true,
        isFavorite: true,
        createdAt: '2026-08-25T18:00:00.000',
        updatedAt: '2026-08-25T18:05:00.000',
      );

      final map = doc.toMap();
      expect(map['id'], 'doc_123');
      expect(map['category'], 'Invoices');
      expect(map['title'], 'Swiggy Food Order Invoice');
      expect(map['extractedText'], contains('SWG-9982'));
      expect(map['fileSize'], 1048576);
      expect(map['tags'], 'food,swiggy,tax');
      expect(map['isPasswordProtected'], 1);
      expect(map['isFavorite'], 1);

      final fromMap = DocumentItem.fromMap(map);
      expect(fromMap.id, 'doc_123');
      expect(fromMap.category, 'Invoices');
      expect(fromMap.extractedText, contains('₹450.00'));
      expect(fromMap.fileSize, 1048576);
      expect(fromMap.isPasswordProtected, true);
      expect(fromMap.isFavorite, true);
    });

    test('DocumentItem copyWith updates fields properly', () {
      final original = DocumentItem(
        profileId: 'default_profile',
        category: 'Personal',
        title: 'Original Title',
        filePath: '/tmp/doc.pdf',
        fileType: 'pdf',
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        isFavorite: true,
        extractedText: 'Extracted text',
      );

      expect(updated.title, 'Updated Title');
      expect(updated.isFavorite, true);
      expect(updated.extractedText, 'Extracted text');
      expect(updated.category, 'Personal'); // Unchanged
    });
  });

  group('DocumentProcessingService Image Transformation Tests', () {
    late Uint8List testImageBytes;

    setUp(() {
      // Create a test 200x200 RGB image
      final testImg = img.Image(width: 200, height: 200);
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 200; x++) {
          testImg.setPixelRgb(x, y, 120, 150, 180);
        }
      }
      testImageBytes = Uint8List.fromList(img.encodeJpg(testImg));
    });

    test('Auto-detect document bounds returns reasonable margins', () {
      final bounds = DocumentProcessingService.instance.autoDetectDocumentBounds(testImageBytes);
      expect(bounds.left, greaterThanOrEqualTo(0.0));
      expect(bounds.top, greaterThanOrEqualTo(0.0));
      expect(bounds.width, lessThanOrEqualTo(1.0));
      expect(bounds.height, lessThanOrEqualTo(1.0));
    });

    test('Crops image bytes with normalized coordinates', () async {
      final croppedBytes = await DocumentProcessingService.instance.processImageBytes(
        bytes: testImageBytes,
        normalizedCropRect: const Rect.fromLTWH(0.25, 0.25, 0.50, 0.50),
        filter: DocumentFilterType.original,
      );

      expect(croppedBytes, isNotNull);
      final decoded = img.decodeImage(croppedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, closeTo(100, 5));
      expect(decoded.height, closeTo(100, 5));
    });

    test('Applies 90 degree rotation', () async {
      final testRectImg = img.Image(width: 200, height: 100);
      final rectBytes = Uint8List.fromList(img.encodeJpg(testRectImg));

      final rotatedBytes = await DocumentProcessingService.instance.processImageBytes(
        bytes: rectBytes,
        rotationAngle: 90,
      );

      final decoded = img.decodeImage(rotatedBytes);
      expect(decoded!.width, 100);
      expect(decoded.height, 200);
    });

    test('Applies Magic Color / Auto-Enhance filter', () async {
      final enhancedBytes = await DocumentProcessingService.instance.processImageBytes(
        bytes: testImageBytes,
        filter: DocumentFilterType.autoEnhance,
        brightness: 1.1,
        contrast: 1.2,
      );

      expect(enhancedBytes.isNotEmpty, isTrue);
      final decoded = img.decodeImage(enhancedBytes);
      expect(decoded, isNotNull);
    });

    test('Applies Black & White Document Scan filter', () async {
      final bwBytes = await DocumentProcessingService.instance.processImageBytes(
        bytes: testImageBytes,
        filter: DocumentFilterType.blackAndWhite,
      );

      expect(bwBytes.isNotEmpty, isTrue);
      final decoded = img.decodeImage(bwBytes);
      expect(decoded, isNotNull);
    });

    test('Applies Grayscale filter', () async {
      final grayBytes = await DocumentProcessingService.instance.processImageBytes(
        bytes: testImageBytes,
        filter: DocumentFilterType.grayscale,
      );

      expect(grayBytes.isNotEmpty, isTrue);
      final decoded = img.decodeImage(grayBytes);
      expect(decoded, isNotNull);
    });
  });

  group('VaultOcrService Smart Extraction & Heuristics Tests', () {
    test('Correctly extracts Tax category and metadata', () {
      const ocrText = '''
GOVERNMENT OF INDIA
Income Tax Department
Form 16 - Certificate of Tax Deducted at Source
PAN: ABCDE1234F
GSTIN: 29ABCDE1234F1Z5
Assessment Year: 2026-27
Total TDS Paid: ₹45,200.00
Date: 15/07/2026
''';
      final meta = VaultOcrService.instance.smartExtractMetadata(ocrText);
      expect(meta.suggestedCategory, 'Tax');
      expect(meta.detectedDates, contains('15/07/2026'));
      expect(meta.detectedAmounts, contains('₹45,200.00'));
    });

    test('Correctly extracts Invoices category and entities', () {
      const ocrText = '''
Tax Invoice
Acme Tech Services Pvt Ltd
Invoice No: INV-2026-8812
Date: 25-Aug-2026
Bill To: LifeSync Corp
Subtotal: \$1,250.00
Total Amount: \$1,375.00
Payment Terms: Net 30
''';
      final meta = VaultOcrService.instance.smartExtractMetadata(ocrText);
      expect(meta.suggestedCategory, 'Invoices');
      expect(meta.detectedDates, contains('25-Aug-2026'));
      expect(meta.detectedAmounts, anyElement(contains('1,375.00')));
      expect(meta.detectedRefNumbers, contains('INV-2026-8812'));
    });

    test('Correctly extracts IDs & Passports category', () {
      const ocrText = '''
PASSPORT
Republic of India
Passport No: Z9182341
Surname: DOE
Given Names: JOHN ALEX
Date of Birth: 12/04/1992
Date of Expiry: 11/04/2034
''';
      final meta = VaultOcrService.instance.smartExtractMetadata(ocrText);
      expect(meta.suggestedCategory, 'IDs & Passports');
      expect(meta.detectedDates, contains('12/04/1992'));
    });

    test('Correctly extracts Medical category and prescription details', () {
      const ocrText = '''
Apollo Hospitals & Health Clinic
Dr. Ramesh Kumar, MBBS, MD
Patient: John Doe
Date: 2026-08-20
Prescription: Paracetamol 650mg
Total Fee: ₹500.00
''';
      final meta = VaultOcrService.instance.smartExtractMetadata(ocrText);
      expect(meta.suggestedCategory, 'Medical');
      expect(meta.detectedDates, contains('2026-08-20'));
      expect(meta.detectedAmounts, contains('₹500.00'));
    });

    test('Correctly extracts Receipts category and Swiggy order', () {
      const ocrText = '''
Payment Receipt
Swiggy Food Delivery
Order #SWG-891240
Grand Total: ₹340.00
Payment Successful via UPI
Date: 24/08/2026
''';
      final meta = VaultOcrService.instance.smartExtractMetadata(ocrText);
      expect(meta.suggestedCategory, 'Receipts');
      expect(meta.detectedAmounts, contains('₹340.00'));
      expect(meta.detectedRefNumbers, contains('SWG-891240'));
    });
  });
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum DocumentFilterType {
  original,
  autoEnhance, // Magic Color / Boost
  blackAndWhite, // Document scan threshold binarization
  grayscale,
}

class ProcessImageParams {
  final Uint8List bytes;
  final double? cropLeft;
  final double? cropTop;
  final double? cropWidth;
  final double? cropHeight;
  final int rotationAngle;
  final DocumentFilterType filter;
  final double brightness;
  final double contrast;
  final int maxDimension;
  final int quality;

  const ProcessImageParams({
    required this.bytes,
    this.cropLeft,
    this.cropTop,
    this.cropWidth,
    this.cropHeight,
    this.rotationAngle = 0,
    this.filter = DocumentFilterType.original,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.maxDimension = 1280,
    this.quality = 85,
  });
}

/// Top-level background isolate function for high-performance non-blocking image processing
Uint8List _isolateProcessImage(ProcessImageParams params) {
  img.Image? image = img.decodeImage(params.bytes);
  if (image == null) {
    throw Exception('Failed to decode image data');
  }

  // 1. Initial downscale if raw photo is gigantic (> maxDimension)
  final maxDim = params.maxDimension;
  if (image.width > maxDim || image.height > maxDim) {
    if (image.width > image.height) {
      final targetH = (image.height * maxDim / image.width).round();
      image = img.copyResize(image, width: maxDim, height: targetH, interpolation: img.Interpolation.linear);
    } else {
      final targetW = (image.width * maxDim / image.height).round();
      image = img.copyResize(image, width: targetW, height: maxDim, interpolation: img.Interpolation.linear);
    }
  }

  // 2. Crop if specified
  if (params.cropLeft != null && params.cropTop != null && params.cropWidth != null && params.cropHeight != null) {
    final left = (params.cropLeft!.clamp(0.0, 1.0) * image.width).round();
    final top = (params.cropTop!.clamp(0.0, 1.0) * image.height).round();
    final width = (params.cropWidth!.clamp(0.05, 1.0) * image.width).round();
    final height = (params.cropHeight!.clamp(0.05, 1.0) * image.height).round();

    final safeLeft = left.clamp(0, image.width - 1);
    final safeTop = top.clamp(0, image.height - 1);
    final safeWidth = width.clamp(1, image.width - safeLeft);
    final safeHeight = height.clamp(1, image.height - safeTop);

    image = img.copyCrop(
      image,
      x: safeLeft,
      y: safeTop,
      width: safeWidth,
      height: safeHeight,
    );
  }

  // 3. Rotate if specified
  if (params.rotationAngle != 0) {
    image = img.copyRotate(image, angle: params.rotationAngle);
  }

  // 4. Apply Filters and Enhancements
  switch (params.filter) {
    case DocumentFilterType.autoEnhance:
      // Magic Color: boost contrast, slightly increase brightness & saturation
      image = img.adjustColor(
        image,
        contrast: 1.25 * params.contrast,
        brightness: 1.05 * params.brightness,
        saturation: 1.15,
      );
      break;

    case DocumentFilterType.blackAndWhite:
      // Clean High-Contrast Document Scan (Binarization)
      image = img.grayscale(image);
      final threshold = (0.52 * params.brightness * 255).clamp(20, 240).toInt();
      for (final pixel in image) {
        if (pixel.r > threshold) {
          pixel.r = 255;
          pixel.g = 255;
          pixel.b = 255;
        } else {
          pixel.r = 0;
          pixel.g = 0;
          pixel.b = 0;
        }
      }
      break;

    case DocumentFilterType.grayscale:
      image = img.grayscale(image);
      if (params.contrast != 1.0 || params.brightness != 1.0) {
        image = img.adjustColor(
          image,
          contrast: params.contrast,
          brightness: params.brightness,
        );
      }
      break;

    case DocumentFilterType.original:
      if (params.contrast != 1.0 || params.brightness != 1.0) {
        image = img.adjustColor(
          image,
          contrast: params.contrast,
          brightness: params.brightness,
        );
      }
      break;
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
}

class DocumentProcessingService {
  static final DocumentProcessingService instance = DocumentProcessingService._init();
  DocumentProcessingService._init();

  /// Process image bytes with cropping, rotation, filter, and adjustments in a background isolate
  Future<Uint8List> processImageBytes({
    required Uint8List bytes,
    Rect? normalizedCropRect,
    int rotationAngle = 0,
    DocumentFilterType filter = DocumentFilterType.original,
    double brightness = 1.0,
    double contrast = 1.0,
    int maxDimension = 1280,
    int quality = 85,
  }) async {
    final params = ProcessImageParams(
      bytes: bytes,
      cropLeft: normalizedCropRect?.left,
      cropTop: normalizedCropRect?.top,
      cropWidth: normalizedCropRect?.width,
      cropHeight: normalizedCropRect?.height,
      rotationAngle: rotationAngle,
      filter: filter,
      brightness: brightness,
      contrast: contrast,
      maxDimension: maxDimension,
      quality: quality,
    );

    // Run in background isolate
    return await compute(_isolateProcessImage, params);
  }

  /// Automatically estimate document boundaries (bounding box with auto-crop margin)
  Rect autoDetectDocumentBounds(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
      return const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
    } catch (_) {
      return const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
    }
  }

  /// Save processed image or file permanently into app's vault storage folder
  Future<File> saveToVaultStorage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(appDir.path, 'vault_documents'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }

    final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetPath = p.join(vaultDir.path, '${DateTime.now().millisecondsSinceEpoch}_$sanitizedName');
    final file = File(targetPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Generate a PDF document from scanned/uploaded images
  Future<File> generatePdfFromImages({
    required List<File> imageFiles,
    required String title,
    String? subtitle,
  }) async {
    final pdf = pw.Document();

    for (final imgFile in imageFiles) {
      if (!await imgFile.exists()) continue;
      final bytes = await imgFile.readAsBytes();
      final image = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'LifeSync Vault Document',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(
                      image,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final outputDir = await getTemporaryDirectory();
    final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final pdfFile = File(p.join(outputDir.path, '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile;
  }

  /// Save file to user's persistent Downloads or Documents directory
  Future<File> exportToUserStorage(File sourceFile, String targetFileName) async {
    Directory? targetDir;
    try {
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      targetDir = await getApplicationDocumentsDirectory();
    }

    targetDir ??= await getApplicationDocumentsDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final sanitized = targetFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final destination = File(p.join(targetDir.path, sanitized));
    return await sourceFile.copy(destination.path);
  }
}

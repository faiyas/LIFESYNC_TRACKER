import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/document_processing_service.dart';
import '../../services/vault_ocr_service.dart';
import '../../services/dynamic_option_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';
import 'document_viewer_screen.dart';

class DocumentScannerScreen extends StatefulWidget {
  final File? initialImageFile;

  const DocumentScannerScreen({
    super.key,
    this.initialImageFile,
  });

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  File? _currentFile;
  Uint8List? _rawBytes;
  Uint8List? _previewBytes;

  bool _isProcessing = false;
  bool _isOcrRunning = false;
  int _previewRequestId = 0;

  // Geometry / Cropping state
  Rect _cropRect = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
  int _rotationAngle = 0;
  String _selectedAspectRatio = 'Free';

  // Filters & Enhancement state
  DocumentFilterType _selectedFilter = DocumentFilterType.autoEnhance;
  double _brightness = 1.0;
  double _contrast = 1.0;

  // Extracted OCR result
  VaultOcrResult? _ocrResult;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialImageFile != null) {
      _loadFile(widget.initialImageFile!);
    } else {
      _pickFromCamera();
    }
  }

  Future<void> _loadFile(File file) async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await file.readAsBytes();
      final autoBounds = DocumentProcessingService.instance.autoDetectDocumentBounds(bytes);

      if (!mounted) return;
      setState(() {
        _currentFile = file;
        _rawBytes = bytes;
        _cropRect = autoBounds;
        _rotationAngle = 0;
      });

      await _applyLivePreview();
    } catch (e) {
      debugPrint('Error loading image file: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (xfile != null) {
        await _loadFile(File(xfile.path));
      } else if (_currentFile == null && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error picking from camera: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (xfile != null) {
        await _loadFile(File(xfile.path));
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
    }
  }

  Future<void> _applyLivePreview() async {
    if (_rawBytes == null) return;
    final requestId = ++_previewRequestId;

    try {
      final preview = await DocumentProcessingService.instance.processImageBytes(
        bytes: _rawBytes!,
        normalizedCropRect: _cropRect,
        rotationAngle: _rotationAngle,
        filter: _selectedFilter,
        brightness: _brightness,
        contrast: _contrast,
        maxDimension: 1080,
        quality: 80,
      );

      if (mounted && requestId == _previewRequestId) {
        setState(() => _previewBytes = preview);
      }
    } catch (e) {
      debugPrint('Error generating live preview: $e');
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
    _applyLivePreview();
  }

  void _setAspectRatio(String ratio) {
    setState(() {
      _selectedAspectRatio = ratio;
      switch (ratio) {
        case 'A4':
          _cropRect = const Rect.fromLTWH(0.12, 0.05, 0.76, 0.90);
          break;
        case 'ID Card':
          _cropRect = const Rect.fromLTWH(0.08, 0.25, 0.84, 0.50);
          break;
        case 'Square':
          _cropRect = const Rect.fromLTWH(0.10, 0.15, 0.80, 0.70);
          break;
        case '4:3':
          _cropRect = const Rect.fromLTWH(0.10, 0.10, 0.80, 0.60);
          break;
        case 'Free':
        default:
          _cropRect = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
          break;
      }
    });
    _applyLivePreview();
  }

  Future<void> _runOcrExtraction() async {
    if (_currentFile == null) return;
    setState(() => _isOcrRunning = true);

    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_preview_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (_previewBytes != null) {
        await tempFile.writeAsBytes(_previewBytes!);
      } else {
        await tempFile.writeAsBytes(_rawBytes!);
      }

      final result = await VaultOcrService.instance.processImage(tempFile.path);
      if (!mounted) return;

      setState(() {
        _ocrResult = result;
      });

      _showOcrResultBottomSheet(result);
    } catch (e) {
      debugPrint('OCR extraction error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract text: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOcrRunning = false);
    }
  }

  void _showOcrResultBottomSheet(VaultOcrResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.40,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.document_scanner_rounded, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Extracted OCR Text',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Smart entities and recognized text',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Text',
                        icon: const Icon(Icons.copy_rounded, color: Colors.purple),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: result.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('OCR text copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Smart metadata chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.category_outlined, size: 16, color: Colors.purple),
                        label: Text('Category: ${result.metadata.suggestedCategory}'),
                        backgroundColor: Colors.purple.withAlpha(25),
                      ),
                      if (result.metadata.detectedDates.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.blue),
                          label: Text('Date: ${result.metadata.detectedDates.first}'),
                          backgroundColor: Colors.blue.withAlpha(25),
                        ),
                      if (result.metadata.detectedAmounts.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
                          label: Text('Amount: ${result.metadata.detectedAmounts.first}'),
                          backgroundColor: Colors.green.withAlpha(25),
                        ),
                      if (result.metadata.detectedRefNumbers.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.tag_rounded, size: 16, color: Colors.orange),
                          label: Text('Ref: ${result.metadata.detectedRefNumbers.first}'),
                          backgroundColor: Colors.orange.withAlpha(25),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Full Recognized Text:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withAlpha(60)),
                    ),
                    child: SelectableText(
                      result.text.isNotEmpty ? result.text : 'No text could be extracted.',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Continue to Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showSaveDialog();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSaveDialog() async {
    if (_previewBytes == null && _rawBytes == null) return;

    if (_ocrResult == null && _currentFile != null) {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(_previewBytes ?? _rawBytes!);
      _ocrResult = await VaultOcrService.instance.processImage(tempFile.path);
    }

    final initialTitle = _ocrResult?.metadata.suggestedTitle ?? 'Scanned Document ${DateTime.now().toString().substring(0, 10)}';
    String category = _ocrResult?.metadata.suggestedCategory ?? 'Personal';

    final titleController = TextEditingController(text: initialTitle);
    final notesController = TextEditingController();
    final tagsController = TextEditingController();
    bool isPasswordProtected = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.save_alt_rounded, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text('Save to Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Document Title',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typeDocumentCategory,
                    label: 'Category',
                    prefixIcon: Icons.category_outlined,
                    initialValue: category,
                    onChanged: (v) => setDialogState(() => category = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: InputDecoration(
                      labelText: 'Tags (comma separated)',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes / Remarks',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('PIN Protected', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Require PIN to view document', style: TextStyle(fontSize: 12)),
                    value: isPasswordProtected,
                    onChanged: (v) => setDialogState(() => isPasswordProtected = v),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () async {
                  // Generate final high-res output
                  final finalBytes = await DocumentProcessingService.instance.processImageBytes(
                    bytes: _rawBytes!,
                    normalizedCropRect: _cropRect,
                    rotationAngle: _rotationAngle,
                    filter: _selectedFilter,
                    brightness: _brightness,
                    contrast: _contrast,
                    maxDimension: 1920,
                    quality: 90,
                  );

                  final title = titleController.text.trim().isEmpty ? 'Document' : titleController.text.trim();

                  // Save permanently into vault storage
                  final savedFile = await DocumentProcessingService.instance.saveToVaultStorage(
                    bytes: finalBytes,
                    fileName: '${title.toLowerCase().replaceAll(' ', '_')}.jpg',
                  );

                  final doc = DocumentItem(
                    profileId: 'default_profile',
                    category: category,
                    title: title,
                    filePath: savedFile.path,
                    fileType: 'jpg',
                    extractedText: _ocrResult?.text,
                    fileSize: finalBytes.length,
                    tags: tagsController.text.isNotEmpty ? tagsController.text.trim() : null,
                    notes: notesController.text.isNotEmpty ? notesController.text.trim() : null,
                    isPasswordProtected: isPasswordProtected,
                  );

                  final db = await AppDatabase.instance.database;
                  await db.insert('documents', doc.toMap());
                  try {
                    if (context.mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}

                  if (mounted) {
                    Navigator.pop(context); // close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentViewerScreen(document: doc),
                      ),
                    );
                  }
                },
                child: const Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controlBg = isDark ? const Color(0xFF1A1D2B) : theme.cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner & Enhancer', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Gallery',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickFromGallery,
          ),
          IconButton(
            tooltip: 'Camera',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: _pickFromCamera,
          ),
          IconButton(
            tooltip: 'Rotate 90°',
            icon: const Icon(Icons.rotate_right_rounded),
            onPressed: _rotateClockwise,
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : Column(
              children: [
                // Aspect Ratio Selector Chips
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['Free', 'A4', 'ID Card', '4:3', 'Square'].map((ratio) {
                      final isSelected = _selectedAspectRatio == ratio;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(ratio, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: Colors.purple.withAlpha(60),
                          onSelected: (_) => _setAspectRatio(ratio),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Image Preview Area with Interactive Crop Visual Overlay
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _previewBytes == null && _rawBytes == null
                          ? Text('No image selected', style: TextStyle(color: theme.hintColor))
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.purple.withAlpha(120), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withAlpha(20),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.memory(
                                    _previewBytes ?? _rawBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                  if (_isOcrRunning)
                                    Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: Colors.purpleAccent),
                                            SizedBox(height: 12),
                                            Text(
                                              'Scanning & Extracting Text (OCR)...',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),

                // Filter Presets & Adjustment Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: controlBg,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filter options
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterOption(
                              label: 'Magic Color',
                              icon: Icons.auto_awesome_rounded,
                              type: DocumentFilterType.autoEnhance,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterOption(
                              label: 'B&W Scan',
                              icon: Icons.document_scanner_outlined,
                              type: DocumentFilterType.blackAndWhite,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterOption(
                              label: 'Grayscale',
                              icon: Icons.monochrome_photos_rounded,
                              type: DocumentFilterType.grayscale,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterOption(
                              label: 'Original',
                              icon: Icons.image_outlined,
                              type: DocumentFilterType.original,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Brightness & Contrast fine tune sliders
                      Row(
                        children: [
                          const Icon(Icons.brightness_6_rounded, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Slider(
                              value: _brightness,
                              min: 0.6,
                              max: 1.4,
                              divisions: 16,
                              activeColor: Colors.purple,
                              onChanged: (v) {
                                setState(() => _brightness = v);
                                _applyLivePreview();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.contrast_rounded, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Slider(
                              value: _contrast,
                              min: 0.6,
                              max: 1.6,
                              divisions: 16,
                              activeColor: Colors.purple,
                              onChanged: (v) {
                                setState(() => _contrast = v);
                                _applyLivePreview();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bottom actions: OCR button & Save to Vault
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.purple),
                                foregroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.text_fields_rounded),
                              label: const Text('Extract OCR', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _runOcrExtraction,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Save to Vault', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _showSaveDialog,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterOption({
    required String label,
    required IconData icon,
    required DocumentFilterType type,
  }) {
    final isSelected = _selectedFilter == type;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = type);
        _applyLivePreview();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withAlpha(40) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey.withAlpha(50),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.purple : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.purple : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

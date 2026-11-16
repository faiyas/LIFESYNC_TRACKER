import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';
import '../../services/document_processing_service.dart';
import '../../services/vault_ocr_service.dart';
import '../../services/dynamic_option_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';
import 'document_scanner_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  final DocumentItem document;

  const DocumentViewerScreen({
    super.key,
    required this.document,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> with SingleTickerProviderStateMixin {
  late DocumentItem _doc;
  late TabController _tabController;
  final TextEditingController _ocrSearchController = TextEditingController();
  String _ocrSearchQuery = '';
  bool _isOcrRunning = false;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ocrSearchController.dispose();
    super.dispose();
  }

  bool get _isImage {
    final ext = _doc.fileType.toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp' || ext == 'image';
  }

  bool get _isPdf {
    final ext = _doc.fileType.toLowerCase();
    return ext == 'pdf';
  }

  Future<void> _toggleFavorite() async {
    final updated = _doc.copyWith(isFavorite: !_doc.isFavorite);
    final db = await AppDatabase.instance.database;
    await db.update('documents', updated.toMap(), where: 'id = ?', whereArgs: [_doc.id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    setState(() => _doc = updated);
  }

  Future<void> _runOcr() async {
    setState(() => _isOcrRunning = true);
    try {
      final res = await VaultOcrService.instance.processImage(_doc.filePath);
      final updated = _doc.copyWith(extractedText: res.text);
      final db = await AppDatabase.instance.database;
      await db.update('documents', updated.toMap(), where: 'id = ?', whereArgs: [_doc.id]);
      try {
        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
        }
      } catch (_) {}

      setState(() {
        _doc = updated;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR completed and saved to document!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOcrRunning = false);
      }
    }
  }

  Future<void> _exportToDevice() async {
    try {
      final file = File(_doc.filePath);
      if (!await file.exists()) {
        throw Exception('Source file does not exist');
      }

      final ext = _doc.fileType.isEmpty ? 'jpg' : _doc.fileType;
      final targetName = '${_doc.title.replaceAll(' ', '_')}.$ext';
      final exported = await DocumentProcessingService.instance.exportToUserStorage(file, targetName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to device: ${exported.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e')),
        );
      }
    }
  }

  Future<void> _exportAsPdf() async {
    try {
      final file = File(_doc.filePath);
      if (!await file.exists()) {
        throw Exception('Source file does not exist');
      }

      if (_isPdf) {
        await _exportToDevice();
        return;
      }

      final pdfFile = await DocumentProcessingService.instance.generatePdfFromImages(
        imageFiles: [file],
        title: _doc.title,
      );

      final exported = await DocumentProcessingService.instance.exportToUserStorage(
        pdfFile,
        '${_doc.title.replaceAll(' ', '_')}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Generated & Saved: ${exported.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export error: $e')),
        );
      }
    }
  }

  Future<void> _printDocument() async {
    try {
      final file = File(_doc.filePath);
      if (!await file.exists()) return;

      if (_isPdf) {
        await ExportService.printPdf(file);
      } else {
        final pdfFile = await DocumentProcessingService.instance.generatePdfFromImages(
          imageFiles: [file],
          title: _doc.title,
        );
        await ExportService.printPdf(pdfFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  Future<void> _editDocumentMetadata() async {
    final titleController = TextEditingController(text: _doc.title);
    final notesController = TextEditingController(text: _doc.notes ?? '');
    final tagsController = TextEditingController(text: _doc.tags ?? '');
    String category = _doc.category;
    bool isPasswordProtected = _doc.isPasswordProtected;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Colors.purple),
                SizedBox(width: 10),
                Text('Edit Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DynamicDropdownField(
                    type: DynamicOptionService.typeDocumentCategory,
                    label: 'Category',
                    prefixIcon: Icons.category_outlined,
                    initialValue: category,
                    onChanged: (v) => setModalState(() => category = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: InputDecoration(
                      labelText: 'Tags',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('PIN Protected', style: TextStyle(fontSize: 14)),
                    value: isPasswordProtected,
                    onChanged: (v) => setModalState(() => isPasswordProtected = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final updated = _doc.copyWith(
                    title: titleController.text.trim().isEmpty ? _doc.title : titleController.text.trim(),
                    category: category,
                    tags: tagsController.text.trim().isEmpty ? null : tagsController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    isPasswordProtected: isPasswordProtected,
                    updatedAt: DateTime.now().toIso8601String(),
                  );

                  final db = await AppDatabase.instance.database;
                  await db.update('documents', updated.toMap(), where: 'id = ?', whereArgs: [_doc.id]);
                  try {
                    if (mounted) {
                      Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                    }
                  } catch (_) {}

                  setState(() => _doc = updated);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Document?'),
        content: const Text('Are you sure you want to permanently delete this document from the Vault?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await AppDatabase.instance.database;
      await db.delete('documents', where: 'id = ?', whereArgs: [_doc.id]);
      try {
        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
        }
      } catch (_) {}

      // Try removing file
      try {
        final f = File(_doc.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}

      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(_doc.filePath);
    final exists = file.existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _doc.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
            icon: Icon(
              _doc.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _doc.isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            tooltip: 'Share Document',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => ExportService.shareFile(_doc.filePath, text: _doc.title),
          ),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              switch (val) {
                case 'save':
                  _exportToDevice();
                  break;
                case 'pdf':
                  _exportAsPdf();
                  break;
                case 'print':
                  _printDocument();
                  break;
                case 're_enhance':
                  if (_isImage) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentScannerScreen(initialImageFile: file),
                      ),
                    );
                  }
                  break;
                case 're_ocr':
                  _runOcr();
                  break;
                case 'edit':
                  _editDocumentMetadata();
                  break;
                case 'delete':
                  _deleteDocument();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text('Save to Device'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print_rounded, color: Colors.teal, size: 20),
                    SizedBox(width: 12),
                    Text('Print Document'),
                  ],
                ),
              ),
              if (_isImage)
                const PopupMenuItem(
                  value: 're_enhance',
                  child: Row(
                    children: [
                      Icon(Icons.crop_rotate_rounded, color: Colors.purple, size: 20),
                      SizedBox(width: 12),
                      Text('Re-crop & Enhance'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 're_ocr',
                child: Row(
                  children: [
                    Icon(Icons.document_scanner_outlined, color: Colors.indigo, size: 20),
                    SizedBox(width: 12),
                    Text('Re-run OCR'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text('Edit Details'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete Document', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          tabs: const [
            Tab(icon: Icon(Icons.visibility_outlined), text: 'Document'),
            Tab(icon: Icon(Icons.text_snippet_outlined), text: 'OCR Text'),
            Tab(icon: Icon(Icons.info_outline_rounded), text: 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Document Viewer Tab
          _buildDocumentTab(file, exists),

          // 2. OCR Text Tab
          _buildOcrTab(),

          // 3. Details & Metadata Tab
          _buildDetailsTab(file, exists),
        ],
      ),
    );
  }

  Widget _buildDocumentTab(File file, bool exists) {
    if (!exists) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Document file not found at:\n${_doc.filePath}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_isImage) {
      return Container(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    if (_isPdf) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, size: 72, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            Text(
              _doc.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'PDF Document • ${_formatBytes(_doc.fileSize ?? file.lengthSync())}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Open / Print PDF'),
                  onPressed: _printDocument,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                  onPressed: () => ExportService.shareFile(_doc.filePath, text: _doc.title),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_rounded, size: 64, color: Colors.purple),
          const SizedBox(height: 12),
          Text(_doc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text('${_doc.fileType.toUpperCase()} file', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOcrTab() {
    final text = _doc.extractedText ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ocrSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search in OCR text...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _ocrSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _ocrSearchController.clear();
                              setState(() => _ocrSearchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onChanged: (v) => setState(() => _ocrSearchQuery = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.purple),
                tooltip: 'Copy Full OCR Text',
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
                onPressed: text.isNotEmpty
                    ? () {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('OCR text copied to clipboard!')),
                        );
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Share OCR Text',
                icon: const Icon(Icons.share_rounded, color: Colors.purple),
                onPressed: text.isNotEmpty ? () => ExportService.shareText(text) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isOcrRunning
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.purple),
                        SizedBox(height: 12),
                        Text('Extracting Text via OCR...'),
                      ],
                    ),
                  )
                : text.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.text_snippet_outlined, size: 56, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No OCR text extracted yet', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.document_scanner_rounded),
                              label: const Text('Extract OCR Now'),
                              onPressed: _runOcr,
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withAlpha(50)),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText.rich(
                            _buildHighlightedText(text, _ocrSearchQuery),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildHighlightedText(String fullText, String query) {
    if (query.isEmpty) {
      return TextSpan(text: fullText);
    }

    final spans = <TextSpan>[];
    final lowerText = fullText.toLowerCase();
    int start = 0;

    while (start < fullText.length) {
      final index = lowerText.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(text: fullText.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: fullText.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: fullText.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.amber,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

  Widget _buildDetailsTab(File file, bool exists) {
    final sizeStr = _formatBytes(_doc.fileSize ?? (exists ? file.lengthSync() : 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.title_rounded, 'Title', _doc.title),
                const Divider(),
                _buildInfoRow(Icons.category_outlined, 'Category', _doc.category),
                const Divider(),
                _buildInfoRow(Icons.extension_rounded, 'File Type', _doc.fileType.toUpperCase()),
                const Divider(),
                _buildInfoRow(Icons.data_usage_rounded, 'File Size', sizeStr),
                const Divider(),
                _buildInfoRow(Icons.calendar_today_outlined, 'Added On', _doc.createdAt.substring(0, 10)),
                if (_doc.tags != null && _doc.tags!.isNotEmpty) ...[
                  const Divider(),
                  _buildInfoRow(Icons.tag_rounded, 'Tags', _doc.tags!),
                ],
                if (_doc.notes != null && _doc.notes!.isNotEmpty) ...[
                  const Divider(),
                  _buildInfoRow(Icons.notes_rounded, 'Notes', _doc.notes!),
                ],
                const Divider(),
                _buildInfoRow(
                  Icons.lock_outline_rounded,
                  'Security',
                  _doc.isPasswordProtected ? 'PIN Protected' : 'Standard Vault Access',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Quick Action Buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ActionChip(
              avatar: const Icon(Icons.download_rounded, size: 18, color: Colors.blue),
              label: const Text('Save to Device'),
              onPressed: _exportToDevice,
            ),
            ActionChip(
              avatar: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.redAccent),
              label: const Text('Export as PDF'),
              onPressed: _exportAsPdf,
            ),
            ActionChip(
              avatar: const Icon(Icons.share_rounded, size: 18, color: Colors.purple),
              label: const Text('Share Document'),
              onPressed: () => ExportService.shareFile(_doc.filePath, text: _doc.title),
            ),
            ActionChip(
              avatar: const Icon(Icons.print_rounded, size: 18, color: Colors.teal),
              label: const Text('Print Document'),
              onPressed: _printDocument,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.purple),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';
import '../../services/dynamic_option_service.dart';
import '../../services/document_processing_service.dart';
import '../../services/vault_ocr_service.dart';
import '../../widgets/dynamic_dropdown_field.dart';
import 'document_scanner_screen.dart';
import 'document_viewer_screen.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  List<DocumentItem> _docs = [];
  bool _isLoading = true;
  int _lastDataVersion = -1;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isGridView = false;
  bool _isVaultLocked = false;
  final LocalAuthentication _auth = LocalAuthentication();

  List<String> categories = ['All', 'Favorites'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: true);
      if (_lastDataVersion != appProvider.dataVersion) {
        _lastDataVersion = appProvider.dataVersion;
        _loadDocs();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocs() async {
    setState(() => _isLoading = true);
    final db = await AppDatabase.instance.database;
    final maps = await db.query('documents', orderBy: 'createdAt DESC');
    final dynamicCats = await DynamicOptionService.instance.getOptions(DynamicOptionService.typeDocumentCategory);

    setState(() {
      _docs = maps.map((e) => DocumentItem.fromMap(e)).toList();
      categories = ['All', 'Favorites', ...dynamicCats];
      _isLoading = false;
    });
  }

  List<DocumentItem> get _filteredDocs {
    return _docs.where((doc) {
      // Category filter
      if (_selectedCategory == 'Favorites') {
        if (!doc.isFavorite) return false;
      } else if (_selectedCategory != 'All') {
        if (doc.category != _selectedCategory) return false;
      }

      // Search query filter (matches title, category, tags, notes, and extractedText from OCR!)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = doc.title.toLowerCase().contains(query);
        final matchCategory = doc.category.toLowerCase().contains(query);
        final matchTags = doc.tags?.toLowerCase().contains(query) ?? false;
        final matchNotes = doc.notes?.toLowerCase().contains(query) ?? false;
        final matchOcr = doc.extractedText?.toLowerCase().contains(query) ?? false;

        if (!matchTitle && !matchCategory && !matchTags && !matchNotes && !matchOcr) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _openScanner({File? initialFile}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentScannerScreen(initialImageFile: initialFile),
      ),
    );
    if (result == true || mounted) {
      _loadDocs();
    }
  }

  Future<void> _pickAndUploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final rawFile = File(file.path!);
        final ext = (file.extension ?? 'pdf').toLowerCase();

        // If user picked an image from file picker, offer scanning/enhancement
        if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          final choice = await showModalBottomSheet<String>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.auto_fix_high_rounded, color: Colors.purple),
                      title: const Text('Enhance & OCR Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Auto-crop, apply filters and extract OCR text'),
                      onTap: () => Navigator.pop(ctx, 'enhance'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.save_rounded, color: Colors.blue),
                      title: const Text('Direct Save'),
                      subtitle: const Text('Save directly without filters or cropping'),
                      onTap: () => Navigator.pop(ctx, 'direct'),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (choice == 'enhance') {
            await _openScanner(initialFile: rawFile);
            return;
          }
        }

        final titleController = TextEditingController(text: file.name);
        String category = categories.firstWhere((c) => c != 'All' && c != 'Favorites', orElse: () => 'Personal');

        if (!mounted) return;

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
                        color: Colors.purple.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.folder_special_outlined, color: Colors.purple),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.description_outlined),
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
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      // Attempt OCR if image
                      String? extractedText;
                      if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
                        final ocr = await VaultOcrService.instance.processImage(rawFile.path);
                        extractedText = ocr.text;
                      }

                      final doc = DocumentItem(
                        profileId: 'default_profile',
                        category: category,
                        title: titleController.text.trim().isEmpty ? file.name : titleController.text.trim(),
                        filePath: rawFile.path,
                        fileType: ext,
                        fileSize: file.size,
                        extractedText: extractedText,
                      );

                      final db = await AppDatabase.instance.database;
                      await db.insert('documents', doc.toMap());
                      try {
                        if (mounted) {
                          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                        }
                      } catch (_) {}
                      if (mounted) Navigator.pop(context);
                      _loadDocs();
                    },
                    child: const Text('Save to Vault', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _showAddDocumentBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x264F46E5),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF6366F1)),
                ),
                title: const Text('Scan with Camera'),
                subtitle: const Text('Capture, auto-crop & extract text (OCR)'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _openScanner();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x2610B981),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                ),
                title: const Text('Upload Image from Gallery'),
                subtitle: const Text('Select photo and run AI OCR'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1920,
                    maxHeight: 1920,
                    imageQuality: 88,
                  );
                  if (xfile != null) {
                    _openScanner(initialFile: File(xfile.path));
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x26F59E0B),
                  child: Icon(Icons.upload_file_rounded, color: Color(0xFFF59E0B)),
                ),
                title: const Text('Upload PDF / File'),
                subtitle: const Text('Import from device storage'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadDocument();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(DocumentItem doc) async {
    final updated = doc.copyWith(isFavorite: !doc.isFavorite);
    final db = await AppDatabase.instance.database;
    await db.update('documents', updated.toMap(), where: 'id = ?', whereArgs: [doc.id]);
    try {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      }
    } catch (_) {}
    _loadDocs();
  }

  Future<void> _deleteDoc(DocumentItem doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Document?'),
        content: Text('Permanently delete "${doc.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await AppDatabase.instance.database;
      await db.delete('documents', where: 'id = ?', whereArgs: [doc.id]);
      try {
        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
        }
      } catch (_) {}
      _loadDocs();
    }
  }

  IconData _fileTypeIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return Icons.image_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'invoices':
        return Colors.blue;
      case 'receipts':
        return Colors.green;
      case 'ids & passports':
      case 'id':
        return Colors.orange;
      case 'medical':
        return Colors.redAccent;
      case 'tax':
        return Colors.teal;
      case 'legal':
        return Colors.indigo;
      case 'education':
        return Colors.deepPurple;
      default:
        return Colors.purple;
    }
  }

  Future<void> _unlockWithBiometrics() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canAuth && !isSupported) {
        setState(() => _isVaultLocked = false);
        return;
      }

      final didAuth = await _auth.authenticate(
        localizedReason: 'Authenticate with Fingerprint or Face ID to unlock Document Vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (didAuth && mounted) {
        setState(() => _isVaultLocked = false);
      }
    } catch (e) {
      debugPrint('Biometric unlock error: $e');
      _showPinFallbackDialog();
    }
  }

  void _showPinFallbackDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Vault PIN 🔐'),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Security PIN',
            hintText: 'Enter 4-digit PIN',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isVaultLocked = false);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _filteredDocs;

    if (_isVaultLocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Secure Document Vault'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 72, color: Colors.purple),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vault is Locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your documents, IDs, medical records & OCR text are encrypted and secured with biometric authentication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _unlockWithBiometrics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 24),
                    label: const Text('Unlock with Biometrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _showPinFallbackDialog,
                  child: const Text('Use Security PIN instead', style: TextStyle(color: Colors.purple)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Lock Vault',
            icon: const Icon(Icons.lock_outline_rounded, color: Colors.purple),
            onPressed: () => setState(() => _isVaultLocked = true),
          ),
          IconButton(
            tooltip: _isGridView ? 'List View' : 'Grid View',
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDocumentBottomSheet,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Scan / Add Document', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search documents, OCR text, tags...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          // Categories Filter Bar
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.purple.withAlpha(50),
                    checkmarkColor: Colors.purple,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Documents List / Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                : docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.purple.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.folder_open_rounded, size: 56, color: Colors.purple),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No documents matching "$_searchQuery"'
                                  : 'No documents in "$_selectedCategory"',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap Scan Document to capture, crop, and OCR docs',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, index) => _buildGridCard(docs[index]),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: docs.length,
                            itemBuilder: (context, index) => _buildListCard(docs[index]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(DocumentItem doc) {
    final catColor = _categoryColor(doc.category);
    final hasOcr = doc.extractedText != null && doc.extractedText!.trim().isNotEmpty;
    final file = File(doc.filePath);
    final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(doc.fileType.toLowerCase());

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentViewerScreen(document: doc),
            ),
          );
          _loadDocs();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail / File Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  color: catColor.withAlpha(35),
                  child: isImg && file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover)
                      : Icon(_fileTypeIcon(doc.fileType), color: catColor, size: 26),
                ),
              ),
              const SizedBox(width: 12),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (doc.isFavorite)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            doc.category,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (hasOcr)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.document_scanner_rounded, size: 10, color: Colors.indigo),
                                SizedBox(width: 2),
                                Text('OCR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              ],
                            ),
                          ),
                        const Spacer(),
                        Text(
                          doc.createdAt.substring(0, 10),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) async {
                  switch (val) {
                    case 'view':
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(document: doc),
                        ),
                      );
                      _loadDocs();
                      break;
                    case 'share':
                      ExportService.shareFile(doc.filePath, text: doc.title);
                      break;
                    case 'fav':
                      _toggleFavorite(doc);
                      break;
                    case 'delete':
                      _deleteDoc(doc);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 18, color: Colors.purple),
                        SizedBox(width: 10),
                        Text('Open & View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, size: 18, color: Colors.blue),
                        SizedBox(width: 10),
                        Text('Share'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'fav',
                    child: Row(
                      children: [
                        Icon(
                          doc.isFavorite ? Icons.star_outline_rounded : Icons.star_rounded,
                          size: 18,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 10),
                        Text(doc.isFavorite ? 'Unfavorite' : 'Favorite'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(DocumentItem doc) {
    final catColor = _categoryColor(doc.category);
    final hasOcr = doc.extractedText != null && doc.extractedText!.trim().isNotEmpty;
    final file = File(doc.filePath);
    final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(doc.fileType.toLowerCase());

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentViewerScreen(document: doc),
            ),
          );
          _loadDocs();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Header
            Expanded(
              child: Container(
                color: catColor.withAlpha(25),
                width: double.infinity,
                child: isImg && file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : Center(
                        child: Icon(_fileTypeIcon(doc.fileType), color: catColor, size: 42),
                      ),
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doc.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doc.isFavorite)
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        doc.category,
                        style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w600),
                      ),
                      if (hasOcr)
                        const Icon(Icons.document_scanner_rounded, size: 12, color: Colors.indigo),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

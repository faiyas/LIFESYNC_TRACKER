import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/dynamic_option_service.dart';

class DynamicDropdownField extends StatefulWidget {
  final String type;
  final String label;
  final IconData prefixIcon;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final bool isDense;

  const DynamicDropdownField({
    super.key,
    required this.type,
    required this.label,
    required this.prefixIcon,
    this.initialValue,
    required this.onChanged,
    this.isDense = false,
  });

  @override
  State<DynamicDropdownField> createState() => _DynamicDropdownFieldState();
}

class _DynamicDropdownFieldState extends State<DynamicDropdownField> {
  List<String> _options = [];
  String? _selectedValue;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void didUpdateWidget(covariant DynamicDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != null && widget.initialValue != _selectedValue) {
      if (_options.contains(widget.initialValue)) {
        setState(() => _selectedValue = widget.initialValue);
      }
    }
  }

  Future<void> _loadOptions({String? selectAfterLoad}) async {
    setState(() => _isLoading = true);
    final list = await DynamicOptionService.instance.getOptions(widget.type);
    if (!mounted) return;

    setState(() {
      _options = list;
      _isLoading = false;

      if (selectAfterLoad != null && _options.contains(selectAfterLoad)) {
        _selectedValue = selectAfterLoad;
        widget.onChanged(selectAfterLoad);
      } else if (_selectedValue != null && !_options.contains(_selectedValue)) {
        _selectedValue = _options.isNotEmpty ? _options.first : null;
        if (_selectedValue != null) widget.onChanged(_selectedValue!);
      } else if (_selectedValue == null && _options.isNotEmpty) {
        if (widget.initialValue != null && _options.contains(widget.initialValue)) {
          _selectedValue = widget.initialValue;
        } else {
          _selectedValue = _options.first;
        }
        widget.onChanged(_selectedValue!);
      }
    });
  }

  void _openManageModal() {
    final addController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(widget.prefixIcon, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Manage ${widget.label}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Add New Input Field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addController,
                          autofocus: _options.isEmpty,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Add new ${widget.label}...',
                            prefixIcon: const Icon(Icons.add),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onSubmitted: (text) async {
                            if (text.trim().isEmpty) return;
                            final added = await DynamicOptionService.instance.addOption(widget.type, text.trim());
                            if (added) {
                              addController.clear();
                              await _loadOptions(selectAfterLoad: text.trim());
                              setModalState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                          onPressed: () async {
                          final text = addController.text.trim();
                          if (text.isEmpty) return;

                          final added = await DynamicOptionService.instance.addOption(widget.type, text);
                          if (added) {
                            addController.clear();
                            await _loadOptions(selectAfterLoad: text);
                            setModalState(() {});
                            if (context.mounted) {
                              try {
                                Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                              } catch (_) {}
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "$text" to ${widget.label}!'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"$text" already exists!'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saved ${widget.label} (${_options.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: _options.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'No ${widget.label.toLowerCase()} added yet.\nType above and tap "Add" to save your first one!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _options.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final opt = _options[idx];
                              final isSelected = opt == _selectedValue;

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                leading: Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected ? Colors.green : Colors.grey,
                                  size: 20,
                                ),
                                title: Text(
                                  opt,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? theme.colorScheme.primary : null,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: 'Delete $opt',
                                  onPressed: () async {
                                    await DynamicOptionService.instance.deleteOption(widget.type, opt);
                                    await _loadOptions();
                                    setModalState(() {});
                                    if (context.mounted) {
                                      try {
                                        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
                                      } catch (_) {}
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted "$opt"'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedValue = opt;
                                  });
                                  widget.onChanged(opt);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.prefixIcon),
          border: const OutlineInputBorder(),
          isDense: widget.isDense,
        ),
        child: const SizedBox(
          height: 20,
          child: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    if (_options.isEmpty) {
      return InkWell(
        onTap: _openManageModal,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('Add', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            border: const OutlineInputBorder(),
            isDense: widget.isDense,
          ),
          child: Text(
            'Tap to add ${widget.label}...',
            style: TextStyle(color: Theme.of(context).hintColor, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _options.contains(_selectedValue) ? _selectedValue : (_options.isNotEmpty ? _options.first : null),
            isDense: widget.isDense,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(widget.prefixIcon),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            items: [
              ..._options.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt, overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedValue = val);
                widget.onChanged(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _openManageModal,
          tooltip: 'Add / Delete ${widget.label}',
          icon: const Icon(Icons.tune_rounded, size: 20),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}

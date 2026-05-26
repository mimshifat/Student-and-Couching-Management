import 'package:flutter/material.dart';

class SearchableDropdown<T, V> extends StatefulWidget {
  final String label;
  final IconData icon;
  final V? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T) itemSearchString;
  final V Function(T) itemValue;
  final void Function(V?) onChanged;
  final String hint;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.itemSearchString,
    required this.itemValue,
    required this.onChanged,
    this.hint = 'Select an item',
  });

  @override
  State<SearchableDropdown<T, V>> createState() => _SearchableDropdownState<T, V>();
}

class _SearchableDropdownState<T, V> extends State<SearchableDropdown<T, V>> {
  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _SearchModal<T>(
          items: widget.items,
          itemLabel: widget.itemLabel,
          itemSearchString: widget.itemSearchString,
          onSelected: (selectedItem) {
            widget.onChanged(widget.itemValue(selectedItem));
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayText = widget.hint;
    if (widget.value != null) {
      try {
        final selectedItem = widget.items.firstWhere((item) => widget.itemValue(item) == widget.value);
        displayText = widget.itemLabel(selectedItem);
      } catch (e) {
        // Value not in list
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4338CA))),
        const SizedBox(height: 4),
        InkWell(
          onTap: _showSearchModal,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.value == null ? Colors.grey.shade600 : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchModal<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T) itemSearchString;
  final void Function(T) onSelected;

  const _SearchModal({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.itemSearchString,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<_SearchModal<T>> createState() => _SearchModalState<T>();
}

class _SearchModalState<T> extends State<_SearchModal<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredItems = widget.items;
      });
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((item) {
        return widget.itemSearchString(item).toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No results found', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          title: Text(widget.itemLabel(item), style: const TextStyle(fontSize: 14)),
                          onTap: () => widget.onSelected(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

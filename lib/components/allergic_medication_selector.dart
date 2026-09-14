import 'package:flutter/material.dart';
import '../../data/database/medication_database.dart';

class AllergicMedicationSelector extends StatefulWidget {
  final List<String> selectedMedications;
  final Function(List<String>) onChanged;

  const AllergicMedicationSelector({
    super.key,
    required this.selectedMedications,
    required this.onChanged,
  });

  @override
  State<AllergicMedicationSelector> createState() =>
      _AllergicMedicationSelectorState();
}

class _AllergicMedicationSelectorState
    extends State<AllergicMedicationSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _allMedications = [];
  List<String> _filteredMedications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedications() async {
    try {
      final medications = await MedicationDatabase.instance.getAllMedications();
      setState(() {
        _allMedications = medications;
        _filteredMedications = medications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterMedications(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMedications = _allMedications;
      } else {
        _filteredMedications = _allMedications
            .where((med) => med.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _toggleMedication(String medication) {
    final newList = List<String>.from(widget.selectedMedications);
    if (newList.contains(medication)) {
      newList.remove(medication);
    } else {
      newList.add(medication);
    }
    widget.onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Tìm kiếm thuốc',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: _filterMedications,
        ),
        const SizedBox(height: 8),
        if (widget.selectedMedications.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.selectedMedications.map((med) {
              return Chip(
                label: Text(med),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _toggleMedication(med),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredMedications.isEmpty
              ? const Center(child: Text('Không tìm thấy thuốc'))
              : ListView.builder(
                  itemCount: _filteredMedications.length,
                  itemBuilder: (context, index) {
                    final medication = _filteredMedications[index];
                    final isSelected = widget.selectedMedications.contains(
                      medication,
                    );
                    return CheckboxListTile(
                      title: Text(medication),
                      value: isSelected,
                      onChanged: (bool? value) {
                        _toggleMedication(medication);
                      },
                      dense: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

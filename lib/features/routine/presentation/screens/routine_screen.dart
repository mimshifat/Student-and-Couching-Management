import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/routine_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../batch/domain/entities/batch.dart';

class RoutineScreen extends StatefulWidget {
  final Batch? initialBatch;

  const RoutineScreen({super.key, this.initialBatch});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  static const Color primaryNavy = Color(0xFF191A4E);
  Batch? _selectedBatch;
  String _selectedPeriod = 'This Week';
  final List<String> _periods = ['This Week', 'Next Week', 'This Month'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final batchProvider = context.read<BatchProvider>();
    await batchProvider.loadBatches();
    
    if (batchProvider.batches.isNotEmpty) {
      setState(() {
        if (widget.initialBatch != null && batchProvider.batches.any((b) => b.id == widget.initialBatch!.id)) {
          _selectedBatch = batchProvider.batches.firstWhere((b) => b.id == widget.initialBatch!.id);
        } else {
          _selectedBatch = batchProvider.batches.first;
        }
      });
      if (mounted) {
        context.read<RoutineProvider>().loadRoutinesByBatch(_selectedBatch!.id!);
      }
    }
  }

  void _onBatchChanged(Batch? newBatch) {
    if (newBatch != null) {
      setState(() {
        _selectedBatch = newBatch;
      });
      context.read<RoutineProvider>().loadRoutinesByBatch(newBatch.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Routine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Consumer<RoutineProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_selectedBatch == null) {
                  return const Center(child: Text('Please create a batch first.', style: TextStyle(color: Colors.black54)));
                }

                if (provider.routines.isEmpty) {
                  return const Center(child: Text('No routines scheduled for this batch.', style: TextStyle(color: Colors.black54)));
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRoutineTable(provider),
                        const SizedBox(height: 24),
                        const Text(
                          '* Routine can be changed anytime',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Consumer<BatchProvider>(
              builder: (context, batchProvider, child) {
                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Batch>(
                      value: _selectedBatch,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                      items: batchProvider.batches.map((b) {
                        return DropdownMenuItem(
                          value: b,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _onBatchChanged,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                  items: _periods.map((p) {
                    return DropdownMenuItem(value: p, child: Text(p));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedPeriod = val!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black87),
              onPressed: () {
                // Navigate to next period if needed
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineTable(RoutineProvider provider) {
    // 1. Determine unique time slots based on the current routines
    // E.g. "7:00 - 8:00", "8:00 - 9:00"
    final Set<String> timeSlotSet = {};
    for (var r in provider.routines) {
      timeSlotSet.add('${r.startTime} - ${r.endTime}');
    }
    
    // Sort time slots alphabetically for simplicity
    final timeSlots = timeSlotSet.toList()..sort();
    
    // 2. Define days
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    // Map standard 'Sunday' to 'Sun' to match routine data if needed.
    // Our DB has 'Sunday', 'Monday', etc.
    final fullDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          border: TableBorder.symmetric(
            inside: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          columnWidths: {
            0: const FixedColumnWidth(60), // Fixed width for Day column
          },
          children: [
            // Header Row
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
              children: [
                _buildTableCell('Day', isHeader: true),
                ...timeSlots.map((ts) => _buildTableCell(ts, isHeader: true)),
              ],
            ),
            // Data Rows
            ...List.generate(days.length, (i) {
              final shortDay = days[i];
              final fullDay = fullDays[i];

              return TableRow(
                children: [
                  _buildTableCell(shortDay, isHeader: true), // Day cell
                  ...timeSlots.map((ts) {
                    // Find subject for this day and time slot
                    final routine = provider.routines.cast<dynamic>().firstWhere(
                      (r) => r.dayOfWeek == fullDay && '${r.startTime} - ${r.endTime}' == ts,
                      orElse: () => null,
                    );
                    return _buildTableCell(routine?.subject ?? '-');
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
            fontSize: isHeader ? 12 : 13,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

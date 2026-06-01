import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/routine_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../batch/domain/entities/batch.dart';
import 'routine_form_screen.dart';
import '../../../../core/widgets/app_drawer.dart';

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
  
  bool _isBatchWise = true;
  String _selectedDay = 'Sunday';
  final List<String> _fullDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> _shortDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateFormat('EEEE').format(DateTime.now());
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

  void _toggleView(bool isBatchWise) {
    setState(() {
      _isBatchWise = isBatchWise;
    });
    if (_isBatchWise) {
      if (_selectedBatch != null) {
        context.read<RoutineProvider>().loadRoutinesByBatch(_selectedBatch!.id!);
      }
    } else {
      context.read<RoutineProvider>().loadRoutinesByDay(_selectedDay);
    }
  }

  void _selectDay(String day) {
    setState(() {
      _selectedDay = day;
    });
    context.read<RoutineProvider>().loadRoutinesByDay(day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: const Text('Routine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoutineFormScreen()),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: primaryNavy, size: 20),
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildViewToggle(),
          if (_isBatchWise) _buildFilterBar() else _buildDaySelector(),
          Expanded(
            child: Consumer<RoutineProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_isBatchWise && _selectedBatch == null) {
                  return const Center(child: Text('Please create a batch first.', style: TextStyle(color: Colors.black54)));
                }

                if (provider.routines.isEmpty) {
                  return Center(
                    child: Text(
                      _isBatchWise ? 'No routines scheduled for this batch.' : 'No routines scheduled for $_selectedDay.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isBatchWise) _buildRoutineTable(provider) else _buildDayWiseList(provider),
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
                    child: DropdownButton<int?>(
                      value: _selectedBatch?.id,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                      items: batchProvider.batches.map((b) {
                        return DropdownMenuItem<int?>(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          try {
                            final newBatch = batchProvider.batches.firstWhere((b) => b.id == val);
                            _onBatchChanged(newBatch);
                          } catch (_) {}
                        }
                      },
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
                  menuMaxHeight: 300,
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
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _toggleView(true),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _isBatchWise ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _isBatchWise ? [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text('Batch Wise', style: TextStyle(fontWeight: _isBatchWise ? FontWeight.bold : FontWeight.normal, color: _isBatchWise ? Colors.black87 : Colors.black54, fontSize: 13)),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _toggleView(false),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: !_isBatchWise ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: !_isBatchWise ? [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text('Day Wise', style: TextStyle(fontWeight: !_isBatchWise ? FontWeight.bold : FontWeight.normal, color: !_isBatchWise ? Colors.black87 : Colors.black54, fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_shortDays.length, (index) {
            final shortDay = _shortDays[index];
            final fullDay = _fullDays[index];
            final isSelected = _selectedDay == fullDay;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(shortDay),
                selected: isSelected,
                selectedColor: primaryNavy,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.grey.shade100,
                onSelected: (selected) {
                  if (selected) _selectDay(fullDay);
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDayWiseList(RoutineProvider provider) {
    final batchProvider = context.read<BatchProvider>();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.routines.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final r = provider.routines[index];
        final batch = batchProvider.batches.firstWhere(
          (b) => b.id == r.batchId, 
          orElse: () => Batch(name: 'Unknown Batch', createdAt: DateTime.now())
        );
        
        String timeStr = '';
        if (r.startTime.isNotEmpty && r.endTime.isNotEmpty) {
          timeStr = '${r.startTime} - ${r.endTime}';
        } else {
          timeStr = batch.timeSlot ?? '';
          if (timeStr.isEmpty && batch.startTime != null && batch.startTime!.isNotEmpty && batch.endTime != null && batch.endTime!.isNotEmpty) {
            timeStr = '${batch.startTime} - ${batch.endTime}';
          }
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_outlined, color: primaryNavy, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.subject,
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    if (r.teacherName != null && r.teacherName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Teacher: ${r.teacherName}',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr.isNotEmpty ? timeStr : '-',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RoutineFormScreen(routine: r)));
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.edit, size: 16, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Routine'),
                              content: const Text('Are you sure you want to delete this routine?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context.read<RoutineProvider>().deleteRoutine(r.id!, r.batchId);
                            if (context.mounted) {
                              context.read<RoutineProvider>().loadRoutinesByDay(_selectedDay);
                            }
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.delete, size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoutineTable(RoutineProvider provider) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
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
                _buildTableCell('Subject', isHeader: true),
              ],
            ),
            // Data Rows
            ...List.generate(days.length, (i) {
              final shortDay = days[i];
              final fullDay = fullDays[i];

              final routinesForDay = provider.routines.where((r) => r.dayOfWeek == fullDay).toList();
              final subjects = routinesForDay.map((r) {
                String timeStr = '';
                if (r.startTime.isNotEmpty && r.endTime.isNotEmpty) {
                  timeStr = '${r.startTime} - ${r.endTime}';
                } else if (_selectedBatch != null) {
                  timeStr = _selectedBatch!.timeSlot ?? '';
                  if (timeStr.isEmpty && _selectedBatch!.startTime != null && _selectedBatch!.startTime!.isNotEmpty && _selectedBatch!.endTime != null && _selectedBatch!.endTime!.isNotEmpty) {
                    timeStr = '${_selectedBatch!.startTime} - ${_selectedBatch!.endTime}';
                  }
                }
                return timeStr.isNotEmpty ? '${r.subject} ($timeStr)' : r.subject;
              }).join('\n');

              return TableRow(
                children: [
                  _buildTableCell(shortDay, isHeader: true),
                  _buildTableCell(subjects.isEmpty ? '-' : subjects),
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

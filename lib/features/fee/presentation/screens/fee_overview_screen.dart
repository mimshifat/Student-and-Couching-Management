import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/common_widgets.dart';
import '../providers/fee_provider.dart';
import 'fee_payment_screen.dart';

class FeeOverviewScreen extends StatefulWidget {
  const FeeOverviewScreen({super.key});

  @override
  State<FeeOverviewScreen> createState() => _FeeOverviewScreenState();
}

class _FeeOverviewScreenState extends State<FeeOverviewScreen> {
  String _searchQuery = '';
  int? _filterMonth;
  int? _filterYear;
  String _filterStatus = 'All'; // All, Paid, Due

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeeProvider>().loadPendingFeeRecords();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter Fees', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    initialValue: _filterStatus,
                    items: ['All', 'Fully Paid', 'Has Dues']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      setSheetState(() => _filterStatus = val ?? 'All');
                      setState(() => _filterStatus = val ?? 'All');
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                          initialValue: _filterMonth,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Months')),
                            ...List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}')))
                          ],
                          onChanged: (val) {
                            setSheetState(() => _filterMonth = val);
                            setState(() => _filterMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                          initialValue: _filterYear,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Years')),
                            ...List.generate(10, (index) {
                              int y = DateTime.now().year - 5 + index;
                              return DropdownMenuItem(value: y, child: Text('$y'));
                            })
                          ],
                          onChanged: (val) {
                            setSheetState(() => _filterYear = val);
                            setState(() => _filterYear = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply Filters'),
                    ),
                  )
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Fee Tracking Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBarWidget(
              hintText: 'Search by student name...',
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: Consumer<FeeProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null) {
                  return Center(child: Text('Error: ${provider.errorMessage}'));
                }

                final filteredRecords = provider.pendingFeeRecords.where((r) {
                  if (_searchQuery.isNotEmpty && r.studentName != null) {
                    if (!r.studentName!.toLowerCase().contains(_searchQuery)) return false;
                  }
                  if (_filterMonth != null && r.month != _filterMonth) return false;
                  if (_filterYear != null && r.year != _filterYear) return false;
                  if (_filterStatus == 'Fully Paid' && r.dueAmount > 0) return false;
                  if (_filterStatus == 'Has Dues' && r.dueAmount <= 0) return false;
                  return true;
                }).toList();

                if (filteredRecords.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No matching fee records found.',
                    icon: Icons.search_off,
                  );
                }

                // Group by student
                final Map<int, List<dynamic>> recordsByStudent = {};
                for (var record in filteredRecords) {
                  if (!recordsByStudent.containsKey(record.studentId)) {
                    recordsByStudent[record.studentId] = [];
                  }
                  recordsByStudent[record.studentId]!.add(record);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: recordsByStudent.length,
                  itemBuilder: (context, index) {
                    final studentId = recordsByStudent.keys.elementAt(index);
                    final records = recordsByStudent[studentId]!;
                    final studentName = records.first.studentName;

                    return AppCard(
                      child: ExpansionTile(
                        initiallyExpanded: _searchQuery.isNotEmpty || _filterMonth != null,
                        title: Text(studentName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Total Due: ৳${records.fold(0.0, (sum, r) => sum + r.dueAmount).toStringAsFixed(0)}', style: const TextStyle(color: Colors.red)),
                        children: records.map((r) {
                          final monthName = DateFormat('MMMM yyyy').format(DateTime(r.year, r.month));
                          return ListTile(
                            dense: true,
                            title: Text(monthName),
                            subtitle: Text('Total: ৳${r.totalAmount.toStringAsFixed(0)} | Paid: ৳${r.paidAmount.toStringAsFixed(0)} | Due: ৳${r.dueAmount.toStringAsFixed(0)}'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => FeePaymentScreen(
                                    studentId: studentId, 
                                    studentName: studentName!,
                                    feeRecord: r,
                                  )),
                                );
                              },
                              child: const Text('Record Payment'),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

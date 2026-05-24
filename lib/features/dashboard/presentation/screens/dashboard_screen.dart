import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../student/presentation/providers/student_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../fee/presentation/providers/fee_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _filterMonth;
  int? _filterYear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<BatchProvider>().loadBatches();
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
                  const Text('Filter Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
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
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (_filterMonth != null || _filterYear != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Filtered by: ${_filterMonth ?? 'All'} / ${_filterYear ?? 'All'}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Consumer<StudentProvider>(
                    builder: (context, provider, _) => StatTile(
                      title: 'Active Students',
                      value: '${provider.students.where((s) => s.status == 'Running').length}',
                      icon: Icons.people,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Consumer<BatchProvider>(
                    builder: (context, provider, _) => StatTile(
                      title: 'Total Batches',
                      value: '${provider.batches.length}',
                      icon: Icons.class_,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<FeeProvider>(
              builder: (context, provider, _) {
                double totalPending = 0;
                for (var r in provider.pendingFeeRecords) {
                  if (_filterMonth != null && r.month != _filterMonth) continue;
                  if (_filterYear != null && r.year != _filterYear) continue;
                  totalPending += r.dueAmount;
                }
                return StatTile(
                  title: 'Uncollected Fees',
                  value: '৳${totalPending.toStringAsFixed(2)}',
                  icon: Icons.monetization_on,
                  color: AppTheme.errorColor,
                );
              },
            ),
            const SizedBox(height: 32),
            const Text('Quick Links', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notes, color: AppTheme.accentColor),
                    title: const Text('My Notes'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushNamed(context, '/notes');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup, color: AppTheme.primaryColor),
                    title: const Text('Backup Settings'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushNamed(context, '/backup');
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

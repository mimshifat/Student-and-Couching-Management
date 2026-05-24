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
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
            if (_filterMonth != null || _filterYear != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Filtered by: ${_filterMonth ?? 'All'} / ${_filterYear ?? 'All'}',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Consumer<StudentProvider>(
                    builder: (context, provider, _) => _buildGradientCard(
                      title: 'Active Students',
                      value: '${provider.students.where((s) => s.status == 'Running').length}',
                      icon: Icons.people_alt_rounded,
                      gradient: AppTheme.primaryGradient,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Consumer<BatchProvider>(
                    builder: (context, provider, _) => _buildGradientCard(
                      title: 'Total Batches',
                      value: '${provider.batches.length}',
                      icon: Icons.class_rounded,
                      gradient: AppTheme.accentGradient,
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
                return _buildGradientCard(
                  title: 'Uncollected Fees',
                  value: '৳${totalPending.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_rounded,
                  gradient: AppTheme.errorGradient,
                  fullWidth: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

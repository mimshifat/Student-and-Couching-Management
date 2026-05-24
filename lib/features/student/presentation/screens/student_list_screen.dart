import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/student_provider.dart';
import '../../../fee/presentation/providers/fee_provider.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _filterStatus = 'All';
  String? _filterClass;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<FeeProvider>().loadPendingFeeRecords();
    });
  }

  void _onSearch(String query) {
    context.read<StudentProvider>().searchStudents(query);
  }

  void _showFilterSheet(List<String> classes) {
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
                  const Text('Filter Students', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    initialValue: _filterStatus,
                    items: ['All', AppConstants.statusRunning, AppConstants.statusPrevious]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      setSheetState(() => _filterStatus = val ?? 'All');
                      setState(() => _filterStatus = val ?? 'All');
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Class', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    initialValue: _filterClass,
                    hint: const Text('All Classes'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Classes')),
                      ...classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (val) {
                      setSheetState(() => _filterClass = val);
                      setState(() => _filterClass = val);
                    },
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
        title: const Text('Students'),
        actions: [
          Consumer<StudentProvider>(
            builder: (context, provider, _) {
              final classes = provider.students.map((e) => e.className).whereType<String>().where((e) => e.isNotEmpty).toSet().toList();
              return IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterSheet(classes),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBarWidget(
              hintText: 'Search by name or phone...',
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: Consumer<StudentProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null) {
                  return Center(child: Text('Error: ${provider.errorMessage}'));
                }

                final students = provider.students.where((s) {
                  bool matchesStatus = _filterStatus == 'All' || s.status == _filterStatus;
                  bool matchesClass = _filterClass == null || s.className == _filterClass;
                  return matchesStatus && matchesClass;
                }).toList();

                if (students.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No students found.',
                    icon: Icons.people_outline,
                  );
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return AppCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(student: student),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            foregroundColor: AppTheme.primaryColor,
                            child: Text(student.name[0].toUpperCase()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () async {
                                    if (student.phone != null && student.phone!.isNotEmpty) {
                                      final url = Uri.parse('tel:${student.phone}');
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      }
                                    }
                                  },
                                  child: Text(
                                    student.phone ?? 'No phone',
                                    style: TextStyle(
                                      color: student.phone != null ? AppTheme.primaryColor : Colors.grey.shade600,
                                      fontSize: 14,
                                      decoration: student.phone != null ? TextDecoration.underline : TextDecoration.none,
                                    ),
                                  ),
                                ),
                                Consumer<FeeProvider>(
                                  builder: (context, feeProvider, _) {
                                    final dues = feeProvider.pendingFeeRecords
                                        .where((r) => r.studentId == student.id)
                                        .fold(0.0, (sum, r) => sum + r.dueAmount);
                                    if (dues > 0) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Dues: ৳${dues.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: AppTheme.errorColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: student.status),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

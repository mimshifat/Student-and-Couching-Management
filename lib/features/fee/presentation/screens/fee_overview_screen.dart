import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/fee_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../student/presentation/providers/student_provider.dart';
import 'fee_payment_screen.dart';
import 'fee_collection_report_screen.dart';
import '../../../../core/widgets/app_drawer.dart';

class FeeOverviewScreen extends StatefulWidget {
  const FeeOverviewScreen({super.key});

  @override
  State<FeeOverviewScreen> createState() => _FeeOverviewScreenState();
}

class _FeeOverviewScreenState extends State<FeeOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedMonth; // null means 'All Months'
  int _selectedYear = DateTime.now().year;
  int? _selectedBatchId;
  Set<int>? _initialUnpaidIds;
  int _lastDataVersion = -1;

  static const Color primaryNavy = Color(0xFF191A4E);

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeeProvider>().loadPendingFeeRecords();
      context.read<BatchProvider>().loadBatches();
      context.read<EnrollmentProvider>().loadEnrollments();
      context.read<StudentProvider>().loadStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Fees', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('Year Selection', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    isExpanded: true,
                    isDense: true,
                    menuMaxHeight: 300,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14),
                    items: List.generate(5, (index) {
                      int y = DateTime.now().year - 2 + index;
                      return DropdownMenuItem(value: y, child: Text('$y'));
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedYear = val);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
        title: const Text('Fees / Payments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Collection Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeeCollectionReportScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _initialUnpaidIds = null;
          await context.read<FeeProvider>().loadPendingFeeRecords(forceRegenerate: true);
        },
        child: Consumer3<FeeProvider, BatchProvider, EnrollmentProvider>(
          builder: (context, feeProvider, batchProvider, enrollmentProvider, child) {
            if (feeProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final batches = batchProvider.batches;
            final enrollments = enrollmentProvider.enrollments;

            if (_lastDataVersion != feeProvider.dataVersion) {
              _initialUnpaidIds = null;
              _lastDataVersion = feeProvider.dataVersion;
            }

            _initialUnpaidIds ??= feeProvider.pendingFeeRecords
                .where((r) => r.paidAmount < r.totalAmount && !r.isSettled)
                .map((r) => r.id!)
                .toSet();

            final allMatchingRecords = feeProvider.pendingFeeRecords.where((r) {
              if (_searchQuery.isNotEmpty && r.studentName != null) {
                if (!r.studentName!.toLowerCase().contains(_searchQuery)) return false;
              }
              if (_selectedMonth != null && r.month != _selectedMonth) return false;
              if (r.year != _selectedYear) return false;
              
              // Batch filter logic
              if (_selectedBatchId != null) {
                if (r.batchId != null) {
                  if (r.batchId != _selectedBatchId) return false;
                } else {
                  // Legacy fallback
                  bool inBatch = enrollments.any((e) => e.studentId == r.studentId && e.batchId == _selectedBatchId);
                  if (!inBatch) return false;
                }
              }
              return true;
            }).toList();

            // Filter records for display (hiding previously paid items)
            final filteredRecords = allMatchingRecords.where((r) {
              bool isPaid = r.paidAmount >= r.totalAmount || r.isSettled;
              if (isPaid && !_initialUnpaidIds!.contains(r.id)) {
                return false;
              }
              return true;
            }).toList();

            // Sort records: studentName first, then month (April -> May -> June)
            filteredRecords.sort((a, b) {
              int nameCompare = (a.studentName ?? '').compareTo(b.studentName ?? '');
              if (nameCompare != 0) return nameCompare;
              return a.month.compareTo(b.month);
            });

            // Calculate summary based on ALL matching records, so users can see their total payments
            double totalFee = allMatchingRecords.fold(0.0, (sum, r) => sum + r.totalAmount);
            double totalPaid = allMatchingRecords.fold(0.0, (sum, r) => sum + r.paidAmount);
            
            // For items that are settled, the remaining difference should be 0 even if paidAmount < totalAmount
            double difference = totalFee - totalPaid;

          return Column(
            children: [
              _buildTopFilters(batches),
              _buildSearchBar(),
              _buildListHeader(),
              Expanded(
                child: _buildFeeList(filteredRecords),
              ),
              _buildSummarySection(totalFee, totalPaid, difference),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildTopFilters(List<dynamic> batches) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedMonth,
                  isExpanded: true,
                  menuMaxHeight: 300,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Months $_selectedYear', overflow: TextOverflow.ellipsis),
                    ),
                    ...List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text('${_months[index]} $_selectedYear', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedMonth = val);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedBatchId,
                  isExpanded: true,
                  menuMaxHeight: 300,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Batches', overflow: TextOverflow.ellipsis)),
                    ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedBatchId = val);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Search by student name',
            hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.black38),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
          Expanded(flex: 2, child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Fee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildFeeList(List<dynamic> records) {
    if (records.isEmpty) {
      return const Center(child: Text('No matching records found.', style: TextStyle(color: Colors.black54)));
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: records.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, index) {
        final r = records[index];
        final total = r.totalAmount;
        final paid = r.paidAmount;
        
        String statusText;
        Color statusBgColor;
        Color statusTextColor;
        
        if (paid >= total || r.isSettled) {
          statusText = 'Paid';
          statusBgColor = const Color(0xFFE8F8EE); // Light green
          statusTextColor = const Color(0xFF2B9348);
        } else if (paid > 0) {
          statusText = 'Due: ৳${(total - paid).toStringAsFixed(0)}';
          statusBgColor = const Color(0xFFFFF3E0); // Light orange
          statusTextColor = const Color(0xFFE65100);
        } else {
          statusText = 'Due: ৳${(total - paid).toStringAsFixed(0)}';
          statusBgColor = const Color(0xFFFFEBEE); // Light red
          statusTextColor = const Color(0xFFC62828);
        }

        String monthName = (r.month >= 1 && r.month <= 12) ? _shortMonths[r.month - 1] : '';

        return InkWell(
          onTap: (paid >= total || r.isSettled) ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FeePaymentScreen(
                studentId: r.studentId, 
                studentName: r.studentName ?? 'Unknown',
                feeRecord: r,
              )),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.studentName ?? 'Unknown', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                      if (r.batchDetailsSnapshot != null && r.batchDetailsSnapshot!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          r.batchDetailsSnapshot!,
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ]
                    ],
                  )
                ),
                Expanded(
                  flex: 2, 
                  child: Text(
                    monthName, 
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
                    textAlign: TextAlign.center,
                  )
                ),
                Expanded(
                  flex: 2, 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '৳ ${total.toStringAsFixed(0)}', 
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      if (paid > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Paid: ৳ ${paid.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF2B9348), fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ]
                    ],
                  ),
                ),
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: (paid >= total || r.isSettled)
                      ? IconButton(
                          icon: const Icon(Icons.message, color: Color(0xFF2B9348)),
                          onPressed: () async {
                            final students = context.read<StudentProvider>().students;
                            final studentList = students.where((s) => s.id == r.studentId);
                            if (studentList.isNotEmpty) {
                              final student = studentList.first;
                              if (student.phone != null && student.phone!.isNotEmpty) {
                                final message = '[CSA]\nDear ${student.name}, your fee payment of ${r.paidAmount.toStringAsFixed(0)} TK for $monthName ${r.year} has been received. Thank you!\n-Abdus Samad';
                                final uri = Uri.parse('sms:${student.phone}?body=${Uri.encodeComponent(message)}');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open messaging app.')));
                                  }
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student has no phone number.')));
                                }
                              }
                            }
                          },
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusTextColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                  )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(double totalFee, double totalPaid, double difference) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Total Fee', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('৳ ${totalFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Total Paid', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('৳ ${totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFF3E0), width: 1.5), // Subtle orange border
                  ),
                  child: Column(
                    children: [
                      const Text('Difference', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('৳ ${difference.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fee_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import 'fee_payment_screen.dart';

class FeeOverviewScreen extends StatefulWidget {
  const FeeOverviewScreen({super.key});

  @override
  State<FeeOverviewScreen> createState() => _FeeOverviewScreenState();
}

class _FeeOverviewScreenState extends State<FeeOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedBatchId;

  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeeProvider>().loadPendingFeeRecords();
      context.read<BatchProvider>().loadBatches();
      context.read<EnrollmentProvider>().loadEnrollments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    // Basic filter sheet for additional options if needed
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
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                initialValue: _selectedYear,
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
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Fees / Payments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Consumer3<FeeProvider, BatchProvider, EnrollmentProvider>(
        builder: (context, feeProvider, batchProvider, enrollmentProvider, child) {
          if (feeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final batches = batchProvider.batches;
          final enrollments = enrollmentProvider.enrollments;

          // Filter records
          final filteredRecords = feeProvider.pendingFeeRecords.where((r) {
            if (_searchQuery.isNotEmpty && r.studentName != null) {
              if (!r.studentName!.toLowerCase().contains(_searchQuery)) return false;
            }
            if (r.month != _selectedMonth) return false;
            if (r.year != _selectedYear) return false;
            
            // Batch filter logic - if selectedBatchId is not null, check if student is enrolled in that batch
            if (_selectedBatchId != null) {
              bool inBatch = enrollments.any((e) => e.studentId == r.studentId && e.batchId == _selectedBatchId);
              if (!inBatch) return false;
            }
            return true;
          }).toList();

          double totalFee = filteredRecords.fold(0.0, (sum, r) => sum + r.totalAmount);
          double totalPaid = filteredRecords.fold(0.0, (sum, r) => sum + r.paidAmount);
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
    );
  }

  Widget _buildTopFilters(List<dynamic> batches) {
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

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
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text('${months[index]} $_selectedYear', overflow: TextOverflow.ellipsis),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMonth = val);
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
      child: Row(
        children: [
          Expanded(
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
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _showFilterSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(Icons.filter_alt_outlined, color: Colors.black54),
            ),
          ),
        ],
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
          Expanded(flex: 2, child: Text('Fee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), textAlign: TextAlign.center)),
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
        
        if (paid >= total) {
          statusText = 'Paid';
          statusBgColor = const Color(0xFFE8F8EE); // Light green
          statusTextColor = const Color(0xFF2B9348);
        } else if (paid > 0) {
          statusText = 'Partial';
          statusBgColor = const Color(0xFFFFF3E0); // Light orange
          statusTextColor = const Color(0xFFE65100);
        } else {
          statusText = 'Unpaid';
          statusBgColor = const Color(0xFFFFEBEE); // Light red
          statusTextColor = const Color(0xFFC62828);
        }

        return InkWell(
          onTap: () {
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
                  child: Text(
                    r.studentName ?? 'Unknown', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                ),
                Expanded(
                  flex: 2, 
                  child: Text(
                    '৳ ${total.toStringAsFixed(0)}', 
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                    textAlign: TextAlign.center,
                  )
                ),
                Expanded(
                  flex: 2, 
                  child: Text(
                    '৳ ${paid.toStringAsFixed(0)}', 
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                    textAlign: TextAlign.center,
                  )
                ),
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: Container(
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

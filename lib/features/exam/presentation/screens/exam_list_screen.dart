import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/exam_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import 'exam_form_screen.dart';
import 'result_entry_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final int _currentYear = DateTime.now().year;
  late int _selectedYear;
  int? _selectedMonth; // null means 'All Months'
  int? _selectedBatchId; // null means 'All Batches'

  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  void initState() {
    super.initState();
    _selectedYear = _currentYear;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamProvider>().loadAllExams();
      context.read<BatchProvider>().loadBatches();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: const Text('Exams', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: primaryNavy, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExamFormScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<ExamProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final exams = provider.exams.where((e) {
            // Search filter
            if (_searchQuery.isNotEmpty && !e.title.toLowerCase().contains(_searchQuery)) {
              return false;
            }
            // Year filter
            if (e.examDate.year != _selectedYear) {
              return false;
            }
            // Month filter
            if (_selectedMonth != null && e.examDate.month != _selectedMonth) {
              return false;
            }
            // Batch filter
            if (_selectedBatchId != null && e.batchId != _selectedBatchId) {
              return false;
            }
            return true;
          }).toList();
          
          // Sort exams by date descending
          exams.sort((a, b) => b.examDate.compareTo(a.examDate));

          return Column(
            children: [
              _buildSearchBar(),
              _buildFiltersRow(),
              const SizedBox(height: 8),
              if (exams.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No exams found.', style: TextStyle(color: Colors.black54)),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: exams.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      return _buildExamCard(exam, provider);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
            hintText: 'Search exam',
            hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.black38),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    // Generate last 5 years up to next year
    final List<int> years = List.generate(7, (index) => _currentYear - 5 + index).reversed.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedYear,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (val) => setState(() => _selectedYear = val!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: _selectedMonth,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Months')),
                        ...List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(months[index]))),
                      ],
                      onChanged: (val) => setState(() => _selectedMonth = val),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Consumer<BatchProvider>(
            builder: (context, batchProvider, _) {
              final batches = batchProvider.batches;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _selectedBatchId,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Batches')),
                      ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => setState(() => _selectedBatchId = val),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }



  Widget _buildExamCard(dynamic exam, ExamProvider provider) {
    // Determine status based on date
    final today = DateTime.now();
    final examDate = exam.examDate;
    final isCompleted = examDate.isBefore(today) || (examDate.year == today.year && examDate.month == today.month && examDate.day == today.day);

    final statusText = isCompleted ? 'Completed' : 'Upcoming';
    final statusBgColor = isCompleted ? const Color(0xFFE8F8EE) : const Color(0xFFEEECFA); // Green vs Purple-ish
    final statusTextColor = isCompleted ? const Color(0xFF2B9348) : const Color(0xFF5A52B8);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultEntryScreen(exam: exam)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              offset: const Offset(0, 2),
              blurRadius: 8,
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAFA), // Light blue background
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFF3B41C5)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Batch: ${exam.batchName ?? 'Unknown'} • ${exam.examType}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(exam.examDate),
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusTextColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExamFormScreen(exam: exam)),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF5A52B8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

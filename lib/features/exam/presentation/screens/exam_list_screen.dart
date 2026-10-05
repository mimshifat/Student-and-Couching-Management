import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/exam_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import 'exam_form_screen.dart';
import 'result_entry_screen.dart';
import '../../../../core/widgets/app_drawer.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  
  final int _currentYear = DateTime.now().year;
  late int _selectedYear;
  late int _startMonth;  // 1-12, defaults to current month
  late int _endMonth;    // 1-12, defaults to current month
  int? _selectedBatchId; // null means 'All Batches'

  static const Color primaryNavy = Color(0xFF191A4E);

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = _currentYear;
    _startMonth = DateTime.now().month;
    _endMonth = DateTime.now().month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExams();
      context.read<BatchProvider>().loadBatches();
    });
  }

  void _loadExams() {
    context.read<ExamProvider>().loadFilteredExams(
      year: _selectedYear,
      startMonth: _startMonth,
      endMonth: _endMonth,
      batchId: _selectedBatchId,
      searchQuery: _searchQuery,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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
        title: const Text('Exams', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: primaryNavy, size: 20),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExamFormScreen()),
              );
              if (mounted) _loadExams();
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

          // Exams are already filtered and sorted at DB level
          final exams = provider.exams;

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
                    addAutomaticKeepAlives: false,
                    itemCount: exams.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      return RepaintBoundary(
                        child: _buildExamCard(exam, provider),
                      );
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
          onChanged: (val) {
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              _searchQuery = val.toLowerCase();
              _loadExams();
            });
          },
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
    // Generate last 5 years up to next year
    final List<int> years = List.generate(7, (index) => _currentYear - 5 + index).reversed.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Year + Month Range row
          Row(
            children: [
              // Year dropdown
              Expanded(
                flex: 3,
                child: _buildDropdownContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      menuMaxHeight: 300,
                      value: _selectedYear,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedYear = val!);
                        _loadExams();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // From month
              Expanded(
                flex: 3,
                child: _buildDropdownContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      menuMaxHeight: 300,
                      value: _startMonth,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthNames[i]),
                      )),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _startMonth = val;
                          // Auto-adjust end month if it's now before start
                          if (_endMonth < _startMonth) {
                            _endMonth = _startMonth;
                          }
                        });
                        _loadExams();
                      },
                    ),
                  ),
                ),
              ),
              // Arrow icon
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 14, color: Colors.black38),
              ),
              // To month
              Expanded(
                flex: 3,
                child: _buildDropdownContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      menuMaxHeight: 300,
                      value: _endMonth,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      // Only show months >= startMonth
                      items: List.generate(12 - _startMonth + 1, (i) => DropdownMenuItem(
                        value: _startMonth + i,
                        child: Text(_monthNames[_startMonth + i - 1]),
                      )),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _endMonth = val);
                        _loadExams();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // "All" chip to quickly reset to full year
              InkWell(
                onTap: () {
                  setState(() {
                    _startMonth = 1;
                    _endMonth = 12;
                  });
                  _loadExams();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_startMonth == 1 && _endMonth == 12)
                        ? primaryNavy
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_startMonth == 1 && _endMonth == 12)
                          ? primaryNavy
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    'All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: (_startMonth == 1 && _endMonth == 12)
                          ? Colors.white
                          : Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Batch dropdown
          Consumer<BatchProvider>(
            builder: (context, batchProvider, _) {
              final batches = batchProvider.batches;
              return _buildDropdownContainer(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    menuMaxHeight: 300,
                    value: _selectedBatchId,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Batches')),
                      ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBatchId = val);
                      _loadExams();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
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
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultEntryScreen(exam: exam)),
        );
        if (mounted) _loadExams();
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
                    'Batch: ${exam.displayBatchName} • ${exam.examType}${exam.examFee != null && exam.examFee > 0 ? ' • Fee: ৳${exam.examFee == exam.examFee.truncateToDouble() ? exam.examFee.toInt() : exam.examFee}' : ''}',
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExamFormScreen(exam: exam)),
                    );
                    if (mounted) _loadExams();
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

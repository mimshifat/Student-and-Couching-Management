import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/student_provider.dart';
import '../../../fee/presentation/providers/fee_provider.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../domain/entities/student.dart';
import '../../../../core/widgets/app_drawer.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String? _filterClass;
  int? _filterBatchId;
  String _statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<FeeProvider>().loadPendingFeeRecords();
      context.read<BatchProvider>().loadBatches();
      context.read<EnrollmentProvider>().loadEnrollments();
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

                  const Text('Class', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _filterClass,
                        isExpanded: true,
                        isDense: true,
                        menuMaxHeight: 300,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14),
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Batch', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Consumer<BatchProvider>(
                    builder: (context, batchProvider, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _filterBatchId,
                            isExpanded: true,
                            isDense: true,
                            menuMaxHeight: 300,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14),
                            hint: const Text('All Batches'),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('All Batches')),
                              ...batchProvider.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                            ],
                            onChanged: (val) {
                              setSheetState(() => _filterBatchId = val);
                              setState(() => _filterBatchId = val);
                            },
                          ),
                        ),
                      );
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

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF5E60CE), // Purple
      const Color(0xFF00B4D8), // Blue
      const Color(0xFF38B000), // Green
      const Color(0xFFF48C06), // Orange
      const Color(0xFFE63946), // Red
    ];
    int hash = name.hashCode;
    return colors[hash % colors.length];
  }

  String _getInitials(String name) {
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  bool _isStudentRunning(Student student, List<dynamic> enrollments) {
    // A student is "Running" if they have an enrollment without a leave date or leave date is in the future
    return enrollments.any((e) => e.studentId == student.id && (e.leaveDate == null || e.leaveDate!.isAfter(DateTime.now())));
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
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Students', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentFormScreen()),
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
      body: Consumer2<StudentProvider, EnrollmentProvider>(
        builder: (context, studentProvider, enrollmentProvider, child) {
          final allStudents = studentProvider.students;
          final classes = allStudents.map((e) => e.className).whereType<String>().where((e) => e.isNotEmpty).toSet().toList();
          final enrollments = enrollmentProvider.enrollments;

          // Apply top-level Class/Batch filters first
          final filteredByClassBatch = allStudents.where((s) {
            bool matchesClass = _filterClass == null || s.className == _filterClass;
            bool matchesBatch = _filterBatchId == null || enrollments.any((e) => e.studentId == s.id && e.batchId == _filterBatchId && e.leaveDate == null);
            return matchesClass && matchesBatch;
          }).toList();

          // Categorize for chips
          final runningStudents = filteredByClassBatch.where((s) => _isStudentRunning(s, enrollments)).toList();
          final previousStudents = filteredByClassBatch.where((s) => !_isStudentRunning(s, enrollments)).toList();
          
          int allCount = filteredByClassBatch.length;
          int runningCount = runningStudents.length;
          int previousCount = previousStudents.length;
          int inactiveCount = 0; // Keeping inactive as 0 or empty for now unless distinct logic exists

          // Apply status filter
          List<Student> displayStudents;
          switch (_statusFilter) {
            case 'Running':
              displayStudents = runningStudents;
              break;
            case 'Previous':
              displayStudents = previousStudents;
              break;
            case 'Inactive':
              displayStudents = []; // Or specific inactive logic
              break;
            case 'All':
            default:
              displayStudents = filteredByClassBatch;
          }

          return Column(
            children: [
              _buildSearchBarRow(classes),
              _buildFilterChipsRow(allCount, runningCount, previousCount, inactiveCount),
              Expanded(
                child: studentProvider.isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _buildStudentList(displayStudents, enrollments),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBarRow(List<String> classes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search by name or phone',
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
            onTap: () => _showFilterSheet(classes),
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

  Widget _buildFilterChipsRow(int allCount, int runningCount, int previousCount, int inactiveCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip('All', count: allCount),
          const SizedBox(width: 8),
          _buildChip('Running', count: runningCount),
          const SizedBox(width: 8),
          _buildChip('Previous', count: previousCount),
          const SizedBox(width: 8),
          _buildChip('Inactive'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {int? count}) {
    bool isSelected = _statusFilter == label;
    String displayText = count != null ? '$label ($count)' : label;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF0FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: isSelected ? const Color(0xFF191A4E) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList(List<Student> students, List<dynamic> enrollments) {
    if (students.isEmpty) {
      return const Center(child: Text('No students found.', style: TextStyle(color: Colors.black54)));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: students.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, index) {
        final student = students[index];
        final isRunning = _isStudentRunning(student, enrollments);
        
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentDetailScreen(student: student),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getAvatarColor(student.name),
                  child: Text(
                    _getInitials(student.name),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Class: ${student.className ?? 'N/A'} • Roll: ${student.rollNumber ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () async {
                          if (student.phone != null && student.phone!.isNotEmpty) {
                            final Uri launchUri = Uri(scheme: 'tel', path: student.phone!);
                            if (await canLaunchUrl(launchUri)) {
                              await launchUrl(launchUri);
                            }
                          }
                        },
                        child: Text(
                          student.phone ?? 'No phone',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRunning ? const Color(0xFFE8F8EE) : const Color(0xFFEEF0FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRunning ? 'Running' : 'Previous',
                    style: TextStyle(
                      color: isRunning ? const Color(0xFF2B9348) : const Color(0xFF5E60CE),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    // Show some bottom sheet or menu for edit/delete
                    _showStudentOptions(student);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.more_vert, size: 20, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStudentOptions(Student student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Student'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentFormScreen(student: student)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Student'),
              onTap: () async {
                Navigator.pop(context);
                final studentProvider = context.read<StudentProvider>();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Student'),
                    content: Text('Are you sure you want to delete ${student.name}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await studentProvider.deleteStudent(student.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

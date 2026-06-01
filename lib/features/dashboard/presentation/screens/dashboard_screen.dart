import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';


import '../../../student/presentation/providers/student_provider.dart';
import '../../../batch/presentation/providers/batch_provider.dart';
import '../../../fee/presentation/providers/fee_provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../../core/widgets/app_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _selectedMonth = DateTime.now().month;
  int? _selectedYear = DateTime.now().year;
  int? _selectedBatchId; // null means all batches

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<BatchProvider>().loadBatches();
      context.read<FeeProvider>().loadPendingFeeRecords();
      context.read<EnrollmentProvider>().loadEnrollments();
    });
  }

  static const Color primaryNavy = Color(0xFF191A4E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
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
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(),
            const SizedBox(height: 24),
            _buildSummaryCards(context),
            const SizedBox(height: 24),
            _buildDifferenceCard(context),
            const SizedBox(height: 32),
            _buildChartSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentYear = DateTime.now().year;
    final List<int> years = List.generate(10, (index) => currentYear - 5 + index);

    return Consumer<BatchProvider>(
      builder: (context, batchProvider, _) {
        final batches = batchProvider.batches;
        
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<int?>(
                    value: _selectedYear,
                    isExpanded: true,
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF2E7D32)),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 300,
                      width: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      offset: const Offset(0, -8),
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600, fontSize: 13),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Years')),
                      ...years.map((y) {
                        return DropdownMenuItem(
                          value: y,
                          child: Text('$y'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedYear = val);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<int?>(
                    value: _selectedMonth,
                    isExpanded: true,
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF2E7D32)),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 300,
                      width: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      offset: const Offset(0, -8),
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600, fontSize: 13),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Months')),
                      ...List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(months[index]),
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
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<int?>(
                    value: _selectedBatchId,
                    isExpanded: true,
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF455A64)),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 300,
                      width: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      offset: const Offset(0, -8),
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    style: const TextStyle(color: Color(0xFF37474F), fontWeight: FontWeight.w600, fontSize: 13),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Batches')),
                      ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBatchId = val);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Consumer3<StudentProvider, EnrollmentProvider, FeeProvider>(
      builder: (context, studentProvider, enrollmentProvider, feeProvider, _) {
        // Calculate Students
        final allStudents = studentProvider.students;
        int activeCount = 0;
        for (var s in allStudents) {
          final enrollments = enrollmentProvider.enrollments.where((e) => e.studentId == s.id).toList();
          final isActive = enrollments.any((e) => e.leaveDate == null || e.leaveDate!.isAfter(DateTime.now()));
          if (isActive) activeCount++;
        }

        // Calculate Fees for selected month/year
        double totalExpected = 0;
        double totalCollected = 0;
        
        for (var r in feeProvider.pendingFeeRecords) {
          if (_selectedMonth != null && r.month != _selectedMonth) continue;
          if (_selectedYear != null && r.year != _selectedYear) continue;
          if (_selectedBatchId != null && r.batchId != _selectedBatchId) continue;
          totalExpected += r.totalAmount;
          totalCollected += r.paidAmount;
        }

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4, // Adjusted for content
          children: [
            _buildDataCard(
              title: 'Total Students',
              value: '${allStudents.length}',
              subtitle: 'All Students',
              iconData: Icons.person_outline_rounded,
              iconColor: const Color(0xFF5E60CE),
              iconBgColor: const Color(0xFFEEF0FE),
            ),
            _buildDataCard(
              title: 'Active Students',
              value: '$activeCount',
              subtitle: 'Currently Active',
              iconData: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF2B9348),
              iconBgColor: const Color(0xFFE8F8EE),
            ),
            _buildDataCard(
              title: 'Total Income',
              value: '৳ ${totalCollected.toStringAsFixed(0)}',
              subtitle: _selectedMonth == null ? (_selectedYear == null ? 'All Time' : 'This Year') : 'This Month',
              iconData: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFF00B4D8),
              iconBgColor: const Color(0xFFE0F7FA),
            ),
            _buildDataCard(
              title: 'Expected Income',
              value: '৳ ${totalExpected.toStringAsFixed(0)}',
              subtitle: _selectedMonth == null ? (_selectedYear == null ? 'All Time' : 'This Year') : 'This Month',
              iconData: Icons.receipt_long_outlined,
              iconColor: const Color(0xFFF48C06),
              iconBgColor: const Color(0xFFFFF3E0),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDifferenceCard(BuildContext context) {
    return Consumer<FeeProvider>(
      builder: (context, feeProvider, _) {
        double totalExpected = 0;
        double totalCollected = 0;
        
        for (var r in feeProvider.pendingFeeRecords) {
          if (_selectedMonth != null && r.month != _selectedMonth) continue;
          if (_selectedYear != null && r.year != _selectedYear) continue;
          if (_selectedBatchId != null && r.batchId != _selectedBatchId) continue;
          totalExpected += r.totalAmount;
          totalCollected += r.paidAmount;
        }
        
        double difference = totalExpected - totalCollected;

        return Container(
          width: MediaQuery.of(context).size.width / 2 - 24, // approx half width to match design layout
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED), // very light orange
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade100, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_late_outlined, color: Color(0xFFEA580C), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Difference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF52525B))),
                    const SizedBox(height: 4),
                    Text(
                      '৳ ${difference.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text('Expected - Received', style: TextStyle(fontSize: 10, color: Color(0xFF71717A))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData iconData,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF52525B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Consumer<FeeProvider>(
      builder: (context, feeProvider, _) {
        final records = feeProvider.pendingFeeRecords;
        
        List<FlSpot> spots = [];
        double maxY = 0;
        
        if (_selectedMonth == null) {
          Map<int, double> monthlyIncome = {};
          for (var r in records) {
            if (_selectedYear == null || r.year == _selectedYear) {
              if (_selectedBatchId == null || r.batchId == _selectedBatchId) {
                monthlyIncome[r.month] = (monthlyIncome[r.month] ?? 0) + r.paidAmount;
              }
            }
          }
          for (int i = 1; i <= 12; i++) {
            double val = monthlyIncome[i] ?? 0;
            spots.add(FlSpot(i.toDouble(), val));
            if (val > maxY) maxY = val;
          }
        } else {
          Map<int, double> dailyIncome = {};
          for (var r in records) {
            if ((_selectedYear == null || r.year == _selectedYear) && r.month == _selectedMonth) {
              if (_selectedBatchId == null || r.batchId == _selectedBatchId) {
                 if (r.paidAmount > 0) {
                   int day = (r.paymentDate ?? r.updatedAt).day;
                   dailyIncome[day] = (dailyIncome[day] ?? 0) + r.paidAmount;
                 }
              }
            }
          }
          List<double> weeklyIncome = [0, 0, 0, 0, 0];
          for (var entry in dailyIncome.entries) {
            int day = entry.key;
            if (day <= 7) {
              weeklyIncome[0] += entry.value;
            } else if (day <= 14) {
              weeklyIncome[1] += entry.value;
            } else if (day <= 21) {
              weeklyIncome[2] += entry.value;
            } else if (day <= 28) {
              weeklyIncome[3] += entry.value;
            } else {
              weeklyIncome[4] += entry.value;
            }
          }
          for (int i = 0; i < 5; i++) {
            spots.add(FlSpot(i.toDouble(), weeklyIncome[i]));
            if (weeklyIncome[i] > maxY) maxY = weeklyIncome[i];
          }
        }
        
        if (maxY == 0) {
          maxY = 10000;
        } else {
          maxY = maxY * 1.2;
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Income Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Text(_selectedMonth == null ? (_selectedYear == null ? 'All Time' : '$_selectedYear') : 'This Month', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF52525B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1, dashArray: const [5, 5]),
                    getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          const style = TextStyle(color: Color(0xFF71717A), fontSize: 11);
                          Widget text = const Text('', style: style);
                          if (_selectedMonth == null) {
                            final List<String> shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            if (value >= 1 && value <= 12) {
                              if (value % 2 != 0) {
                                 text = Text(shortMonths[value.toInt() - 1], style: style);
                              }
                            }
                          } else {
                            switch (value.toInt()) {
                              case 0: text = const Text('W1', style: style); break;
                              case 1: text = const Text('W2', style: style); break;
                              case 2: text = const Text('W3', style: style); break;
                              case 3: text = const Text('W4', style: style); break;
                              case 4: text = const Text('W5', style: style); break;
                            }
                          }
                          return SideTitleWidget(meta: meta, child: text);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxY > 50000 ? (maxY / 5) : (maxY == 10000 ? 2000 : maxY / 5),
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value >= 1000 ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k' : value.toInt().toString(),
                            style: const TextStyle(color: Color(0xFF71717A), fontSize: 11),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: _selectedMonth == null ? 1 : 0,
                  maxX: _selectedMonth == null ? 12 : 4,
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF3B82F6),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF3B82F6),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6).withValues(alpha: 0.15),
                            const Color(0xFF3B82F6).withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => const Color(0xFF1E293B),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          return LineTooltipItem(
                            '৳ ${touchedSpot.y.toInt()}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

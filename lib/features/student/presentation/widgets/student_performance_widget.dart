import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../exam/domain/entities/detailed_result.dart';
import '../../../exam/data/repositories/exam_repository_impl.dart';

// ────────────────────────────────────────────────────────────────────────────
// Colour palette shared across all charts
// ────────────────────────────────────────────────────────────────────────────
const _navy = Color(0xFF191A4E);
const _indigo = Color(0xFF3B41C5);
const _green = Color(0xFF2B9348);
const _orange = Color(0xFFF57C00);
const _red = Color(0xFFD32F2F);


class StudentPerformanceWidget extends StatefulWidget {
  final int studentId;

  const StudentPerformanceWidget({super.key, required this.studentId});

  @override
  State<StudentPerformanceWidget> createState() =>
      _StudentPerformanceWidgetState();
}

class _StudentPerformanceWidgetState extends State<StudentPerformanceWidget> {
  bool _isLoading = true;
  List<DetailedResult> _allResults = [];
  int? _selectedYear;

  // For bar-chart tooltip
  int? _touchedBarIndex;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    // Use addPostFrameCallback so we never call setState inside initState
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResults());
  }

  Future<void> _loadResults() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = ExamRepositoryImpl();
      final results = await repo.getDetailedResultsForStudent(widget.studentId);
      if (mounted) {
        setState(() {
          _allResults = results;
        });
      }
    } catch (e) {
      // Even on error, clear the spinner so the user isn't stuck
      debugPrint('StudentPerformanceWidget: error loading results: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Unique years from all results (descending).
  List<int> get _years {
    final set = _allResults.map((r) => r.examDate.year).toSet();
    if (_selectedYear != null) set.add(_selectedYear!);
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Results filtered by the selected year (or all if null).
  List<DetailedResult> get _yearResults {
    if (_selectedYear == null) return _allResults;
    return _allResults
        .where((r) => r.examDate.year == _selectedYear)
        .toList();
  }

  /// Only present (non-absent) results with marks.
  List<DetailedResult> get _scoredResults =>
      _yearResults.where((r) => !r.isAbsent && r.obtainedMarks != null).toList();

  // ── Summary stats ──────────────────────────────────────────────────────────

  _SummaryStats _computeStats() {
    final all = _yearResults;
    if (all.isEmpty) return _SummaryStats.empty();
    final scored = _scoredResults;
    final absents = all.length - scored.length;
    if (scored.isEmpty) {
      return _SummaryStats(
        total: all.length,
        absents: absents,
        average: 0,
        highest: 0,
        lowest: 0,
        totalObtained: 0,
        totalAvailable: 0,
      );
    }
    double obtained = 0, available = 0, high = 0, low = double.infinity;
    for (final r in scored) {
      obtained += r.obtainedMarks!;
      available += r.totalMarks;
      final pct = (r.obtainedMarks! / r.totalMarks) * 100;
      if (pct > high) high = pct;
      if (pct < low) low = pct;
    }
    return _SummaryStats(
      total: all.length,
      absents: absents,
      average: available > 0 ? (obtained / available) * 100 : 0,
      highest: high,
      lowest: low == double.infinity ? 0 : low,
      totalObtained: obtained,
      totalAvailable: available,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _computeStats();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Year filter ──────────────────────────────────────────────────
          _buildYearFilter(),
          const SizedBox(height: 16),

          // ── Empty state ──────────────────────────────────────────────────
          if (_yearResults.isEmpty)
            _buildEmptyState()
          else ...[
            // ── KPI summary row ──────────────────────────────────────────
            _buildSummaryBanner(stats),
            const SizedBox(height: 20),

            // ── KPI stat cards ───────────────────────────────────────────
            _buildStatCards(stats),
            const SizedBox(height: 20),

            // ── 1. Line chart – score trend ──────────────────────────────
            _buildSectionHeader(
                Icons.show_chart, 'Score Trend', 'Marks per exam over time'),
            const SizedBox(height: 12),
            _buildLineTrendChart(),
            const SizedBox(height: 20),

            // ── 2. Bar chart – monthly average ───────────────────────────
            _buildSectionHeader(Icons.bar_chart, 'Monthly Average',
                'Average score % by month'),
            const SizedBox(height: 12),
            _buildMonthlyBarChart(),
            const SizedBox(height: 20),

            // ── 3. Pie chart – attendance overview ───────────────────────
            _buildSectionHeader(Icons.donut_large, 'Attendance Overview',
                'Present vs absent exams'),
            const SizedBox(height: 12),
            _buildAttendancePie(stats),
            const SizedBox(height: 20),

            // ── 4. Grade distribution bar ────────────────────────────────
            _buildSectionHeader(Icons.stacked_bar_chart, 'Grade Distribution',
                'Results by performance band'),
            const SizedBox(height: 12),
            _buildGradeDistribution(),
            const SizedBox(height: 20),

            // ── 5. Subject / batch breakdown ─────────────────────────────
            _buildSectionHeader(
                Icons.category, 'Batch Breakdown', 'Performance per batch'),
            const SizedBox(height: 12),
            _buildBatchBreakdown(),
            const SizedBox(height: 20),

            // ── 6. Recent exam cards ─────────────────────────────────────
            _buildSectionHeader(
                Icons.history, 'Recent Exams', 'Latest results'),
            const SizedBox(height: 12),
            _buildRecentExamCards(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Year filter chip row
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildYearFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _yearChip(null, 'All Years'),
          ..._years.map((y) => _yearChip(y, y.toString())),
        ],
      ),
    );
  }

  Widget _yearChip(int? year, String label) {
    final selected = _selectedYear == year;
    return GestureDetector(
      onTap: () => setState(() => _selectedYear = year),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _indigo : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _indigo : Colors.grey.shade300),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: _indigo.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Empty state
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedYear == null
                ? 'No exam results yet'
                : 'No results for $_selectedYear',
            style: const TextStyle(fontSize: 16, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          const Text(
            'Results will appear here once exams are recorded.',
            style: TextStyle(fontSize: 13, color: Colors.black38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Summary banner (gradient card)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildSummaryBanner(_SummaryStats s) {
    final label =
        _selectedYear == null ? 'All Time Performance' : 'Performance $_selectedYear';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF2D3080)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _navy.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _bannerStat('Average', '${s.average.toStringAsFixed(1)}%'),
              _bannerStat('Highest', '${s.highest.toStringAsFixed(0)}%'),
              _bannerStat('Exams', s.total.toString()),
              _bannerStat('Absents', s.absents.toString()),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (s.average / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                  s.average >= 70 ? _green : s.average >= 40 ? _orange : _red),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${s.totalObtained.toStringAsFixed(1)} / ${s.totalAvailable.toStringAsFixed(1)} marks total',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      );

  // ────────────────────────────────────────────────────────────────────────────
  // Stat cards row
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStatCards(_SummaryStats s) {
    return Row(
      children: [
        Expanded(
            child: _statCard('Lowest', '${s.lowest.toStringAsFixed(0)}%',
                Icons.arrow_downward, _red)),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard('Scored', s.totalObtained.toStringAsFixed(0),
                Icons.grade, _indigo)),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard('Available',
                s.totalAvailable.toStringAsFixed(0), Icons.book, _orange)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87)),
          const SizedBox(height: 3),
          Text(title,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Section header
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _indigo, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87)),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
      ],
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: child,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 1. Line trend chart (score %)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildLineTrendChart() {
    // chronological order for the trend
    final sorted = List<DetailedResult>.from(_yearResults)
      ..sort((a, b) => a.examDate.compareTo(b.examDate));

    if (sorted.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final pct = r.isAbsent || r.obtainedMarks == null
          ? 0.0
          : (r.obtainedMarks! / r.totalMarks) * 100;
      spots.add(FlSpot(i.toDouble(), double.parse(pct.toStringAsFixed(1))));
    }

    return _cardShell(
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.grey.shade100,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                      style:
                          const TextStyle(fontSize: 9, color: Colors.black38)),
                  interval: 20,
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval:
                      sorted.length > 6 ? (sorted.length / 6).ceilToDouble() : 1,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < sorted.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('d MMM').format(sorted[idx].examDate),
                          style: const TextStyle(
                              fontSize: 9, color: Colors.black38),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (sorted.length - 1).toDouble().clamp(1, double.infinity),
            minY: 0,
            maxY: 110,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: _indigo,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, p1, p2, idx) {
                    final r = sorted[idx];
                    final absent = r.isAbsent || r.obtainedMarks == null;
                    return FlDotCirclePainter(
                      radius: 5,
                      color: absent ? _red : _indigo,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      _indigo.withValues(alpha: 0.18),
                      _indigo.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // 40% pass line
              LineChartBarData(
                spots: [
                  FlSpot(0, 40),
                  FlSpot((sorted.length - 1).toDouble().clamp(1, double.infinity), 40),
                ],
                isCurved: false,
                color: _orange.withValues(alpha: 0.5),
                barWidth: 1.5,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => _navy,
                getTooltipItems: (spots) {
                  return spots.map((s) {
                    if (s.barIndex == 1) return null; // skip pass line
                    final idx = s.x.toInt();
                    if (idx < 0 || idx >= sorted.length) return null;
                    final r = sorted[idx];
                    final absent = r.isAbsent || r.obtainedMarks == null;
                    return LineTooltipItem(
                      absent
                          ? '${r.examTitle}\nAbsent'
                          : '${r.examTitle}\n${s.y.toStringAsFixed(1)}%',
                      TextStyle(
                        color: absent ? _red : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 2. Monthly average bar chart
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildMonthlyBarChart() {
    // Build monthly avg from scored results only
    final monthMap = <int, _MonthStat>{};
    for (final r in _scoredResults) {
      final m = r.examDate.month;
      monthMap.putIfAbsent(m, () => _MonthStat());
      monthMap[m]!.add((r.obtainedMarks! / r.totalMarks) * 100);
    }

    if (monthMap.isEmpty) {
      return _cardShell(
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: Text('No scored data',
                  style: TextStyle(color: Colors.black38))),
        ),
      );
    }

    final months = monthMap.keys.toList()..sort();
    final abbr = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final avg = monthMap[m]!.average;
      final touched = _touchedBarIndex == i;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: double.parse(avg.toStringAsFixed(1)),
            color: touched ? _orange : _indigo,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: Colors.grey.shade100,
            ),
          ),
        ],
      ));
    }

    return _cardShell(
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchCallback: (e, resp) {
                setState(() {
                  _touchedBarIndex =
                      (resp != null && resp.spot != null && !e.isInterestedForInteractions)
                          ? resp.spot!.touchedBarGroupIndex
                          : null;
                });
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _navy,
                getTooltipItem: (group, gIdx, rod, rIdx) {
                  final m = months[gIdx];
                  return BarTooltipItem(
                    '${abbr[m]}\n${rod.toY.toStringAsFixed(1)}%',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                      style:
                          const TextStyle(fontSize: 9, color: Colors.black38)),
                  interval: 25,
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < months.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(abbr[months[idx]],
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            barGroups: groups,
            maxY: 100,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 3. Attendance pie chart
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildAttendancePie(_SummaryStats s) {
    final present = s.total - s.absents;
    if (s.total == 0) return const SizedBox.shrink();

    final sections = [
      PieChartSectionData(
        value: present.toDouble(),
        color: _green,
        title: '$present\nPresent',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      if (s.absents > 0)
        PieChartSectionData(
          value: s.absents.toDouble(),
          color: _red,
          title: '${s.absents}\nAbsent',
          radius: 60,
          titleStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];

    final presentPct = (present / s.total * 100).toStringAsFixed(0);

    return _cardShell(
      child: Row(
        children: [
          SizedBox(
            height: 160,
            width: 160,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legend(_green, 'Present ($present)', '$presentPct%'),
                const SizedBox(height: 12),
                _legend(_red, 'Absent (${s.absents})',
                    '${(s.absents / s.total * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 16),
                Text('Attendance rate',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black45)),
                Text('$presentPct%',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: int.parse(presentPct) >= 75 ? _green : _red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, String pct) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54))),
        Text(pct,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 4. Grade distribution
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildGradeDistribution() {
    int excellent = 0, good = 0, average = 0, poor = 0;
    for (final r in _scoredResults) {
      final pct = (r.obtainedMarks! / r.totalMarks) * 100;
      if (pct >= 80) { excellent++; }
      else if (pct >= 60) { good++; }
      else if (pct >= 40) { average++; }
      else { poor++; }
    }

    final total = _scoredResults.length;
    if (total == 0) {
      return _cardShell(
        child: const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text('No scored data',
                    style: TextStyle(color: Colors.black38)))),
      );
    }

    return _cardShell(
      child: Column(
        children: [
          _gradeBand('Excellent (≥80%)', excellent, total,
              const Color(0xFF1B5E20), const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
          _gradeBand('Good (60–79%)', good, total, const Color(0xFF0D47A1),
              const Color(0xFF2196F3)),
          const SizedBox(height: 12),
          _gradeBand('Average (40–59%)', average, total,
              const Color(0xFFE65100), _orange),
          const SizedBox(height: 12),
          _gradeBand('Poor (<40%)', poor, total, const Color(0xFFB71C1C), _red),
        ],
      ),
    );
  }

  Widget _gradeBand(
      String label, int count, int total, Color dark, Color light) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(light),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text('$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: dark)),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 5. Batch breakdown
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildBatchBreakdown() {
    final batchMap = <String, _BatchStat>{};
    for (final r in _yearResults) {
      final name = r.displayBatchName;
      batchMap.putIfAbsent(name, () => _BatchStat());
      batchMap[name]!.add(r);
    }

    if (batchMap.isEmpty) return const SizedBox.shrink();

    final entries = batchMap.entries.toList()
      ..sort((a, b) => b.value.average.compareTo(a.value.average));

    return Column(
      children: entries.map((e) {
        final stat = e.value;
        final avg = stat.average;
        final color = avg >= 70 ? _green : avg >= 40 ? _orange : _red;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.group, color: _navy, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(e.key,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${avg.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (avg / 100).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pill(Icons.assignment, '${stat.total} exams',
                      const Color(0xFF1A73E8)),
                  const SizedBox(width: 6),
                  _pill(Icons.person_off, '${stat.absents} absent', _red),
                  const SizedBox(width: 6),
                  _pill(Icons.score,
                      '${stat.obtained.toStringAsFixed(0)}/${stat.available.toStringAsFixed(0)} pts',
                      _green),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 6. Recent exam cards (last 5)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildRecentExamCards() {
    final sorted = List<DetailedResult>.from(_yearResults)
      ..sort((a, b) => b.examDate.compareTo(a.examDate));
    final recent = sorted.take(5).toList();

    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      children: recent.map((r) {
        final absent = r.isAbsent || r.obtainedMarks == null;
        final pct = absent
            ? 0.0
            : (r.obtainedMarks! / r.totalMarks) * 100;
        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (absent) {
          statusColor = _red;
          statusIcon = Icons.cancel;
          statusText = 'Absent';
        } else {
          if (pct >= 80) {
            statusColor = _green;
            statusIcon = Icons.verified;
          } else if (pct >= 40) {
            statusColor = _orange;
            statusIcon = Icons.check_circle;
          } else {
            statusColor = _red;
            statusIcon = Icons.warning;
          }
          statusText =
              '${r.obtainedMarks!.toStringAsFixed(1)}/${r.totalMarks.toStringAsFixed(0)}';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.assignment, color: _navy, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.examTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87)),
                    const SizedBox(height: 3),
                    Text(
                        '${r.displayBatchName} • ${r.examType}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.black45)),
                    Text(
                        DateFormat('dd MMM yyyy').format(r.examDate),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.black38)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(statusText,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: statusColor)),
                      const SizedBox(width: 4),
                      Icon(statusIcon, color: statusColor, size: 15),
                    ],
                  ),
                  if (!absent) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: statusColor)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Small data helpers
// ────────────────────────────────────────────────────────────────────────────

class _SummaryStats {
  final int total;
  final int absents;
  final double average;
  final double highest;
  final double lowest;
  final double totalObtained;
  final double totalAvailable;

  _SummaryStats({
    required this.total,
    required this.absents,
    required this.average,
    required this.highest,
    required this.lowest,
    required this.totalObtained,
    required this.totalAvailable,
  });

  factory _SummaryStats.empty() => _SummaryStats(
        total: 0,
        absents: 0,
        average: 0,
        highest: 0,
        lowest: 0,
        totalObtained: 0,
        totalAvailable: 0,
      );
}

class _MonthStat {
  double _sum = 0;
  int _count = 0;
  void add(double pct) {
    _sum += pct;
    _count++;
  }

  double get average => _count == 0 ? 0 : _sum / _count;
}

class _BatchStat {
  int total = 0;
  int absents = 0;
  double obtained = 0;
  double available = 0;

  void add(DetailedResult r) {
    total++;
    if (r.isAbsent || r.obtainedMarks == null) {
      absents++;
    } else {
      obtained += r.obtainedMarks!;
      available += r.totalMarks;
    }
  }

  double get average =>
      available > 0 ? (obtained / available) * 100 : 0;
}

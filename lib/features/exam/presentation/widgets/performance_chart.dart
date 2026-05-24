import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';

class PerformanceChart extends StatelessWidget {
  final List<ExamResult> results;

  const PerformanceChart({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('No exam data available for chart.', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    // Prepare data points
    List<FlSpot> spots = [];
    double maxMark = 100.0; // Fallback max
    for (int i = 0; i < results.length; i++) {
      if (!results[i].isAbsent && results[i].obtainedMarks != null) {
        spots.add(FlSpot(i.toDouble(), results[i].obtainedMarks!));
        if (results[i].obtainedMarks! > maxMark) {
          maxMark = results[i].obtainedMarks!;
        }
      } else if (results[i].isAbsent) {
        // Plot absent as 0 so it's visible on the chart timeline explicitly
        spots.add(FlSpot(i.toDouble(), 0));
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < results.length) {
                          // Show short date
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM d').format(results[index].createdAt),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (results.length - 1).toDouble() > 0 ? (results.length - 1).toDouble() : 1,
                minY: 0,
                maxY: maxMark + 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index >= 0 && index < results.length && results[index].isAbsent) {
                          return LineTooltipItem(
                            'Absent',
                            const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          );
                        }
                        return LineTooltipItem(
                          '${spot.y}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          // Legend for absents
          if (results.any((r) => r.isAbsent))
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  Container(width: 12, height: 12, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Missing exams (Absent)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
        ],
      ),
    );
  }
}

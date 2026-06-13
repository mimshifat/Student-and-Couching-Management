import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/annual_report_entry.dart';
import '../providers/annual_report_provider.dart';

class AnnualReportScreen extends StatefulWidget {
  const AnnualReportScreen({super.key});

  @override
  State<AnnualReportScreen> createState() => _AnnualReportScreenState();
}

class _AnnualReportScreenState extends State<AnnualReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pass current year; provider will load available years and auto-select
      context.read<AnnualReportProvider>().loadReport(DateTime.now().year);
    });
  }

  // ── palette ──────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF3B41C5);
  static const _bg = Color(0xFFF4F6F9);
  static const _textDark = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFab(),
      body: Consumer<AnnualReportProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }
          if (provider.errorMessage != null) {
            return _buildError(provider.errorMessage!);
          }
          return _buildBody(provider);
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Annual Report',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _textDark,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        Consumer<AnnualReportProvider>(
          builder: (ctx, provider, child) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildYearDropdown(provider),
          ),
        ),
      ],
    );
  }

  Widget _buildYearDropdown(AnnualReportProvider provider) {
    final years = provider.availableYears;
    if (years.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // pill shape
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: years.contains(provider.selectedYear) ? provider.selectedYear : years.first,
          icon: const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B5563), size: 20),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
          onChanged: (y) {
            if (y == null) return;
            provider.loadReport(y);
          },
        ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFab() {
    return Consumer<AnnualReportProvider>(
      builder: (ctx, provider, child) => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: FloatingActionButton.extended(
          onPressed: provider.entries.isEmpty || provider.isLoading ? null : () => _exportPdf(provider),
          backgroundColor: _primary,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          label: const Text('Export PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Future<void> _exportPdf(AnnualReportProvider provider) async {
    try {
      await provider.exportToPdf();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create PDF: $e')),
      );
    }
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(AnnualReportProvider provider) {
    if (provider.entries.isEmpty) {
      return _buildEmpty(provider.selectedYear);
    }
    return Column(
      children: [
        _buildSummaryCard(provider.entries.length, provider.selectedYear),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: provider.entries.length,
            itemBuilder: (context, index) => _buildStudentCard(index + 1, provider.entries[index]),
          ),
        ),
      ],
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(int total, int year) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF283593), Color(0xFF3F51B5)], // sleek indigo/blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Enrolled',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Students',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Student card ──────────────────────────────────────────────────────────

  Widget _buildStudentCard(int serial, AnnualReportEntry entry) {
    final isDeleted = entry.studentName == '[Deleted Student]';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Serial badge
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDeleted ? Colors.red.shade50 : const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    serial.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDeleted ? Colors.red.shade400 : _primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.studentName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDeleted ? Colors.red.shade300 : const Color(0xFF1A1D2E),
                          decoration: isDeleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (entry.phone != null && entry.phone!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone_android_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              entry.phone!,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        )
                      else
                        Text('No Phone Number', style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                if (isDeleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Deleted', style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            
            // Batches section
            if (entry.batches.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 16),
              ...entry.batches.map((b) => _buildSleekBatchRow(b)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSleekBatchRow(BatchInfo batch) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.class_outlined, size: 16, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        batch.batchName ?? 'Unknown Batch',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF374151)),
                      ),
                    ),
                    if (batch.studentClass != null && batch.studentClass!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F6FD),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          batch.studentClass!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]
                  ],
                ),
                if (_scheduleText(batch).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text(
                        _scheduleText(batch),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _scheduleText(BatchInfo batch) {
    final parts = [batch.scheduleDays, batch.timeSlot]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.join(' • ');
  }

  // ── Empty / Error states ──────────────────────────────────────────────────

  Widget _buildEmpty(int year) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                )
              ]
            ),
            child: Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            'No students enrolled in $year',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 12),
            Text('An error occurred:\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

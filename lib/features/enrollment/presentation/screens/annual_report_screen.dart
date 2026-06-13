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
  static const _primary = Color(0xFF1A73E8);
  static const _bg = Color(0xFFF4F7FE);
  static const _cardBg = Colors.white;

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
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Consumer<AnnualReportProvider>(
        builder: (ctx, provider, child) => Text(
          'বার্ষিক রিপোর্ট - ${provider.selectedYear}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      actions: [
        Consumer<AnnualReportProvider>(
          builder: (ctx, provider, child) => Padding(
            padding: const EdgeInsets.only(right: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: years.contains(provider.selectedYear)
              ? provider.selectedYear
              : years.first,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: _primary, size: 18),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _primary),
          dropdownColor: Colors.white,
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
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
      builder: (ctx, provider, child) => FloatingActionButton.extended(
        onPressed: provider.entries.isEmpty || provider.isLoading
            ? null
            : () => _exportPdf(provider),
        backgroundColor: _primary,
        disabledElevation: 0,
        icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
        label: const Text('PDF Save',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _exportPdf(AnnualReportProvider provider) async {
    try {
      await provider.exportToPdf();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF তৈরি করতে সমস্যা: $e')),
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
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: provider.entries.length,
            itemBuilder: (context, index) =>
                _buildStudentCard(index + 1, provider.entries[index]),
          ),
        ),
      ],
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(int total, int year) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$total জন ছাত্রছাত্রী',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
              '$year সালের রিপোর্ট',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header row ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDeleted
                  ? Colors.red.shade50
                  : const Color(0xFFF0F6FF),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Serial badge
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? Colors.red.shade100
                        : const Color(0xFFE8F0FE),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$serial',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDeleted
                          ? Colors.red.shade700
                          : _primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.studentName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDeleted
                                    ? Colors.red.shade700
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isDeleted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Deleted',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (entry.phone != null && entry.phone!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13,
                                color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              entry.phone!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── batch list ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.batches.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${entry.batches.length}টি ব্যাচে ভর্তি হয়েছিল',
                      style: TextStyle(
                        fontSize: 11,
                        color: _primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ...entry.batches.asMap().entries.map(
                      (e) => _buildBatchRow(e.key, e.value,
                          entry.batches.length > 1),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchRow(int index, BatchInfo batch, bool showIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE8FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIndex)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 1),
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    fontSize: 10,
                    color: _primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _infoChip(
                  Icons.school_outlined,
                  batch.batchName ?? 'ব্যাচ অজানা',
                  const Color(0xFF1A73E8),
                  const Color(0xFFE8F0FE),
                ),
                _infoChip(
                  Icons.class_outlined,
                  batch.studentClass ?? 'ক্লাস অজানা',
                  const Color(0xFF2B9348),
                  const Color(0xFFE8F8EE),
                ),
                if (_scheduleText(batch).isNotEmpty)
                  _infoChip(
                    Icons.schedule_outlined,
                    _scheduleText(batch),
                    const Color(0xFFF57C00),
                    const Color(0xFFFFF3E0),
                  ),
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

  Widget _infoChip(
      IconData icon, String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Empty / Error states ──────────────────────────────────────────────────

  Widget _buildEmpty(int year) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '$year সালে কোনো ছাত্রছাত্রী ভর্তি হয়নি',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
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
            Text('সমস্যা হয়েছে:\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

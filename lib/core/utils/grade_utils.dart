import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../../features/exam/domain/entities/detailed_result.dart';

/// Bangladesh Education Board GPA 5.0 Grading Scale utility.
///
/// Grading scale:
///   80–100%  →  A+  (5.00)
///   70–79%   →  A   (4.00)
///   60–69%   →  A-  (3.50)
///   50–59%   →  B   (3.00)
///   40–49%   →  C   (2.00)
///   33–39%   →  D   (1.00)
///    0–32%   →  F   (0.00)
class GradeUtils {
  GradeUtils._(); // Prevent instantiation

  /// Returns the letter grade for a given percentage.
  /// Returns '-' if percentage is null (absent / no data).
  static String getGrade(double? percentage) {
    if (percentage == null) return '-';
    if (percentage >= 80) return 'A+';
    if (percentage >= 70) return 'A';
    if (percentage >= 60) return 'A-';
    if (percentage >= 50) return 'B';
    if (percentage >= 40) return 'C';
    if (percentage >= 33) return 'D';
    return 'F';
  }

  /// Returns the grade point (0.00 – 5.00) for a given percentage.
  /// Returns null if percentage is null (absent / no data).
  static double? getGradePoint(double? percentage) {
    if (percentage == null) return null;
    if (percentage >= 80) return 5.00;
    if (percentage >= 70) return 4.00;
    if (percentage >= 60) return 3.50;
    if (percentage >= 50) return 3.00;
    if (percentage >= 40) return 2.00;
    if (percentage >= 33) return 1.00;
    return 0.00;
  }

  /// Returns the letter grade corresponding to a cumulative GPA (0.00 - 5.00).
  /// BD standard scale:
  ///   5.00        → A+
  ///   4.00 - 4.99 → A
  ///   3.50 - 3.99 → A-
  ///   3.00 - 3.49 → B
  ///   2.00 - 2.99 → C
  ///   1.00 - 1.99 → D
  ///   < 1.00      → F
  static String getGradeFromGPA(double? gpa) {
    if (gpa == null) return '-';
    if (gpa >= 5.0) return 'A+';
    if (gpa >= 4.0) return 'A';
    if (gpa >= 3.5) return 'A-';
    if (gpa >= 3.0) return 'B';
    if (gpa >= 2.0) return 'C';
    if (gpa >= 1.0) return 'D';
    return 'F';
  }

  /// Whether the student passes (>= 33%).
  static bool isPassing(double? percentage) {
    if (percentage == null) return false;
    return percentage >= 33;
  }

  /// Calculates weighted overall GPA from a list of [DetailedResult].
  ///
  /// Weight = totalMarks of each exam (a 100-mark exam weighs more than 25-mark).
  /// Absent results are excluded from calculation.
  /// Returns null if no valid (non-absent) results exist.
  static double? calculateOverallGPA(List<DetailedResult> results) {
    double weightedSum = 0;
    double totalWeight = 0;

    for (final r in results) {
      if (r.isAbsent || r.obtainedMarks == null || r.totalMarks <= 0) continue;
      final gp = getGradePoint(r.percentage);
      if (gp == null) continue;
      weightedSum += gp * r.totalMarks;
      totalWeight += r.totalMarks;
    }

    if (totalWeight == 0) return null;
    return weightedSum / totalWeight;
  }

  /// Returns a Flutter [Color] for the given grade (for UI usage).
  static Color getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
        return const Color(0xFF1B5E20); // Dark green
      case 'A':
        return const Color(0xFF2B9348); // Green
      case 'A-':
        return const Color(0xFF558B2F); // Light green
      case 'B':
        return const Color(0xFF1A73E8); // Blue
      case 'C':
        return const Color(0xFFF57C00); // Orange
      case 'D':
        return const Color(0xFFE65100); // Deep orange
      case 'F':
        return const Color(0xFFD32F2F); // Red
      default:
        return const Color(0xFF757575); // Grey (absent / no data)
    }
  }

  /// Returns a PDF [PdfColor] for the given grade (for PDF generation).
  static PdfColor getGradePdfColor(String grade) {
    switch (grade) {
      case 'A+':
        return PdfColors.green900;
      case 'A':
        return PdfColors.green700;
      case 'A-':
        return PdfColors.lightGreen800;
      case 'B':
        return PdfColors.blue700;
      case 'C':
        return PdfColors.orange700;
      case 'D':
        return PdfColors.deepOrange700;
      case 'F':
        return PdfColors.red700;
      default:
        return PdfColors.grey600;
    }
  }

  /// Formats grade point for display: "5.00", "4.00", etc.
  /// Returns '-' if null.
  static String formatGradePoint(double? gp) {
    if (gp == null) return '-';
    return gp.toStringAsFixed(2);
  }
}


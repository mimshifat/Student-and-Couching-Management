class AppConstants {
  // Route Names
  static const String routeDashboard = '/';
  static const String routeStudentList = '/students';
  static const String routeStudentDetail = '/student-detail';
  static const String routeStudentForm = '/student-form';
  static const String routeBatchList = '/batches';
  static const String routeBatchDetail = '/batch-detail';
  static const String routeBatchForm = '/batch-form';
  static const String routeEnrollment = '/enrollment';
  static const String routeExamList = '/exams';
  static const String routeExamForm = '/exam-form';
  static const String routeResultEntry = '/result-entry';
  static const String routeFeeOverview = '/fees';
  static const String routeStudentFeeDetail = '/student-fees';
  static const String routePaymentForm = '/payment-form';
  static const String routeSettings = '/settings';
  static const String routeRoutine = '/routine';
  static const String routeNotes = '/notes';
  static const String routeBackup = '/backup';

  // Statuses
  static const String statusRunning = 'Running';
  static const String statusPrevious = 'Previous';

  static const List<String> studentStatuses = [statusRunning, statusPrevious];

  // Days of Week
  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
}

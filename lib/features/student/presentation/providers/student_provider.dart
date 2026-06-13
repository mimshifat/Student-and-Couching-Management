import 'package:flutter/foundation.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/student_summary.dart';
import '../../domain/repositories/student_repository.dart';

class StudentProvider with ChangeNotifier {
  final StudentRepository _repository;

  List<Student> _students = [];
  List<Student> get students => _students;

  List<StudentSummary> _studentSummaries = [];
  List<StudentSummary> get studentSummaries => _studentSummaries;

  /// Distinct class names from DB — populated by loadDistinctClassNames().
  /// Much cheaper than loading all students just for the filter dropdown.
  List<String> _distinctClassNames = [];
  List<String> get distinctClassNames => _distinctClassNames;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StudentProvider(this._repository) {
    loadStudents();
  }

  Future<void> loadStudentSummaries({
    String? className,
    int? batchId,
    String? searchQuery,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _studentSummaries = await _repository.getFilteredStudentSummaries(
        className: className,
        batchId: batchId,
        searchQuery: searchQuery,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _students = await _repository.getAllStudents();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads only distinct class names from DB — O(distinct classes) not O(all students).
  Future<void> loadDistinctClassNames() async {
    try {
      _distinctClassNames = await _repository.getDistinctClassNames();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  /// Fetches only the phone number of one student — avoids loading all 5,300 students.
  Future<String?> fetchStudentPhone(int studentId) async {
    try {
      return await _repository.getStudentPhoneById(studentId);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<void> searchStudents(String query) async {
    if (query.isEmpty) {
      await loadStudents();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _students = await _repository.searchStudents(query);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudentsByBatch(int batchId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _students = await _repository.getStudentsByBatch(batchId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int?> addStudent(Student student) async {
    try {
      final id = await _repository.insertStudent(student);
      await loadStudents();
      return id;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateStudent(Student student) async {
    try {
      await _repository.updateStudent(student);
      await loadStudents();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStudent(int id) async {
    try {
      await _repository.deleteStudent(id);
      await loadStudents();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

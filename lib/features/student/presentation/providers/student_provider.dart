import 'package:flutter/foundation.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/student_repository.dart';

class StudentProvider with ChangeNotifier {
  final StudentRepository _repository;

  List<Student> _students = [];
  List<Student> get students => _students;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StudentProvider(this._repository) {
    loadStudents();
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

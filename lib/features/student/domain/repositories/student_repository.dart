import '../entities/student.dart';

abstract class StudentRepository {
  Future<int> insertStudent(Student student);
  Future<int> updateStudent(Student student);
  Future<int> deleteStudent(int id);
  Future<Student?> getStudentById(int id);
  Future<List<Student>> getAllStudents();
  Future<List<Student>> searchStudents(String query);
}

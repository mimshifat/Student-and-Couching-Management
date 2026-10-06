import '../entities/institute_profile.dart';

abstract class ProfileRepository {
  Future<InstituteProfile?> getProfile();
  Future<void> saveProfile(InstituteProfile profile);
}

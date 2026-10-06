import 'package:flutter/foundation.dart';
import '../../domain/entities/institute_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository;

  InstituteProfile? _profile;
  bool _isLoading = true;

  InstituteProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  ProfileProvider(this._repository) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = await _repository.getProfile();

    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> reloadProfile() async {
    await _loadProfile();
  }

  Future<void> saveProfile(InstituteProfile profile) async {
    await _repository.saveProfile(profile);
    _profile = profile;
    notifyListeners();
  }
}

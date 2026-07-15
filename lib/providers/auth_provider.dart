import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UserModel? _user;
  String? _profilePhotoPath;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserModel? get user => _user;
  String? get profilePhotoPath => _profilePhotoPath;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    _isLoading = true;
    notifyListeners();
    
    String? userData = await _storage.read(key: 'user_data');
    if (userData != null) {
      _user = UserModel.fromJson(jsonDecode(userData));
      _profilePhotoPath = await _storage.read(key: 'profile_photo_path_${_user!.id}');
      
      // Edge-case: check if offline for more than 15 minutes
      final role = _user!.role.toLowerCase();
      if (role == 'dse' || role == 'tl') {
        String? startStr = await _storage.read(key: 'break_start_time');
        String? totalSecStr = await _storage.read(key: 'total_break_seconds');
        if (startStr != null) {
          int totalSeconds = int.tryParse(totalSecStr ?? '0') ?? 0;
          DateTime startTime = DateTime.fromMillisecondsSinceEpoch(int.parse(startStr));
          totalSeconds += DateTime.now().difference(startTime).inSeconds;
          if (totalSeconds >= 15) {
            // Force logout
            await logout(isForced: true);
          }
        }
      }
    }
    
    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _tryStartTracking() async {
    if (_user == null) return;
    final role = _user!.role.toLowerCase();
    if (role != 'dse' && role != 'tl') return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      FlutterBackgroundService().startService();
    }
  }

  Future<void> login(String phone, String password, {String? otp}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get or generate a persistent unique device ID
      String? deviceId = await _storage.read(key: 'device_id');
      if (deviceId == null) {
        final randomVal = DateTime.now().millisecondsSinceEpoch.toString() + 
            '-' + 
            (100000 + (DateTime.now().microsecond % 900000)).toString();
        deviceId = randomVal;
        await _storage.write(key: 'device_id', value: deviceId);
      }

      final response = await _apiService.post('login.php', {
        'phone': phone,
        'password': password,
        'otp': otp,
        'device_id': deviceId,
        'platform': 'app',
      });

      if (response['status'] == 'success') {
        _user = UserModel.fromJson(response['user']);
        await _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));
        await _storage.write(key: 'session_token', value: 'dummy_token_for_session');
        await _storage.delete(key: 'otp_required');
        
        // Removed _tryStartTracking() from here. 
        // DSEDashboard will handle starting the service after checking permissions.
      } else {
        throw Exception(response['message']);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    try {
      final response = await _apiService.get('get_profile.php');
      if (response['status'] == 'success') {
        _user = UserModel.fromJson(response['user']);
        await _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
  }

  Future<void> updateUserEmail(String newEmail) async {
    if (_user == null) return;
    _user = UserModel(
      id: _user!.id,
      name: _user!.name,
      phone: _user!.phone,
      role: _user!.role,
      email: newEmail,
      managerId: _user!.managerId,
      tlId: _user!.tlId,
      tlName: _user!.tlName,
    );
    await _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));
    notifyListeners();
    try {
      await _apiService.post('update_profile.php', {
        'email': newEmail,
      });
    } catch (e) {
      debugPrint('Error syncing email update with server: $e');
    }
  }

  Future<void> updateProfilePhotoPath(String newPath) async {
    if (_user == null) return;
    _profilePhotoPath = newPath;
    await _storage.write(key: 'profile_photo_path_${_user!.id}', value: newPath);
    notifyListeners();
  }

  Future<void> logout({bool isForced = false}) async {
    try {
      await _apiService.get('logout_user.php');
      FlutterBackgroundService().invoke('stopService');
    } catch (_) {}
    
    _profilePhotoPath = null;
    _user = null;
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'session_token');
    await _storage.delete(key: 'session_cookie');
    if (isForced) {
      await _storage.write(key: 'otp_required', value: 'true');
    } else {
      await _storage.delete(key: 'otp_required');
    }
    notifyListeners();
  }
}

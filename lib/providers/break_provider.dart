import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class BreakProvider with ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  int _totalBreakSeconds = 0;
  DateTime? _breakStartTime;
  bool _isOffline = false;
  Timer? _ticker;

  int get totalBreakSeconds => _totalBreakSeconds;
  bool get isOffline => _isOffline;

  // Calculate current total including the active break session
  int get currentSessionSeconds {
    if (_breakStartTime == null) return _totalBreakSeconds;
    return _totalBreakSeconds + DateTime.now().difference(_breakStartTime!).inSeconds;
  }

  String get formattedTime {
    int total = currentSessionSeconds;
    int minutes = total ~/ 60;
    int seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  BreakProvider() {
    loadFromStorage();
  }

  Future<void> loadFromStorage() async {
    String? total = await _storage.read(key: 'total_break_seconds');
    String? start = await _storage.read(key: 'break_start_time');
    String? lastDate = await _storage.read(key: 'last_break_date');

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastDate != null && lastDate != today) {
      // New day, reset everything
      await resetForNewDay();
    } else {
      if (total != null) _totalBreakSeconds = int.parse(total);
      if (start != null) {
        _breakStartTime = DateTime.fromMillisecondsSinceEpoch(int.parse(start));
        _isOffline = true;
        _startTicker();
      } else {
        _totalBreakSeconds = 0;
        await _storage.write(key: 'total_break_seconds', value: '0');
        _breakStartTime = null;
        _isOffline = false;
        _ticker?.cancel();
      }
    }
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    final startDay = DateTime.now().day;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (DateTime.now().day != startDay) {
        resetForNewDay();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> startBreak() async {
    if (_isOffline) return;
    
    _isOffline = true;
    _breakStartTime = DateTime.now();
    await _storage.write(key: 'break_start_time', value: _breakStartTime!.millisecondsSinceEpoch.toString());
    await _storage.write(key: 'last_break_date', value: DateFormat('yyyy-MM-dd').format(_breakStartTime!));
    
    _startTicker();
    notifyListeners();
  }

  Future<void> stopBreak() async {
    _totalBreakSeconds = 0;
    _isOffline = false;
    _breakStartTime = null;
    _ticker?.cancel();

    await _storage.write(key: 'total_break_seconds', value: '0');
    await _storage.delete(key: 'break_start_time');
    
    notifyListeners();
  }

  Future<void> resetForNewDay() async {
    _totalBreakSeconds = 0;
    _breakStartTime = null;
    _isOffline = false;
    _ticker?.cancel();

    await _storage.write(key: 'total_break_seconds', value: '0');
    await _storage.delete(key: 'break_start_time');
    await _storage.write(key: 'last_break_date', value: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

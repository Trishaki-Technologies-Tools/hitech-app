import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Timer? _refreshTimer;
  List<dynamic> _attendanceLogs = [];
  DateTime _selectedDate = DateTime.now();
  String _officeHours = '9:00 AM - 6:00 PM';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchLogs();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchLogs(showLoading: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) _fetchLogs(showLoading: false);
    }
  }

  String _formatOfficeHours(String? login, String? logout) {
    if (login == null || logout == null) return '9:00 AM - 6:00 PM';
    try {
      final loginTime = DateFormat('HH:mm').parse(login);
      final logoutTime = DateFormat('HH:mm').parse(logout);
      return '${DateFormat('h:mm a').format(loginTime)} - ${DateFormat('h:mm a').format(logoutTime)}';
    } catch (_) {
      return '$login - $logout';
    }
  }

  Future<void> _fetchLogs({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await _apiService.get('tracking.php?type=attendance&start_date=$dateStr&end_date=$dateStr');
      
      if (mounted) {
        setState(() {
          _attendanceLogs = res['data'] ?? [];
          final settings = res['settings'];
          if (settings != null) {
            _officeHours = _formatOfficeHours(settings['login_time'], settings['logout_time']);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching logs: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchLogs();
    }
  }

  String _formatTime(String? time) {
    if (time == null) return '--:--:--';
    try {
      final dt = DateTime.parse(time);
      return DateFormat('hh:mm:ss a').format(dt);
    } catch (e) {
      return '--:--:--';
    }
  }

  String _formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  Map<String, String> _calculateTotals() {
    int totalLoginSeconds = 0;
    int totalBreakSeconds = 0;
    
    final reversedLogs = _attendanceLogs.reversed.toList();
    for (int i = 0; i < reversedLogs.length; i++) {
        final log = reversedLogs[i];
        final loginTime = log['login_time'];
        final logoutTime = log['logout_time'];
        
        if (loginTime != null) {
            final loginDt = DateTime.parse(loginTime);
            DateTime endDt = logoutTime != null ? DateTime.parse(logoutTime) : DateTime.now();
            totalLoginSeconds += endDt.difference(loginDt).inSeconds;
            
            if (i > 0) {
                final prevLog = reversedLogs[i - 1];
                final prevLogoutTime = prevLog['logout_time'];
                if (prevLogoutTime != null) {
                    final prevLogoutDt = DateTime.parse(prevLogoutTime);
                    int breakSecs = loginDt.difference(prevLogoutDt).inSeconds;
                    if (breakSecs > 0) totalBreakSeconds += breakSecs;
                }
            }
        }
    }
    
    return {
      'login': _formatDuration(totalLoginSeconds),
      'break': _formatDuration(totalBreakSeconds),
    };
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 110.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDate.day == DateTime.now().day && 
                      _selectedDate.month == DateTime.now().month && 
                      _selectedDate.year == DateTime.now().year 
                        ? 'Today' 
                        : DateFormat('EEEE').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F51B5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month, color: Color(0xFF3F51B5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Working hours: $_officeHours',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isLoading && _attendanceLogs.isNotEmpty)
              Builder(
                builder: (context) {
                  final totals = _calculateTotals();
                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.timer, color: Colors.green, size: 20),
                              const SizedBox(height: 4),
                              const Text('Total Login', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(totals['login']!, style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.coffee, color: Colors.orange, size: 20),
                              const SizedBox(height: 4),
                              const Text('Total Break', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(totals['break']!, style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 32),
            Text(
              _selectedDate.day == DateTime.now().day && 
              _selectedDate.month == DateTime.now().month && 
              _selectedDate.year == DateTime.now().year 
                ? 'Today\'s Activity' 
                : 'Activity',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_attendanceLogs.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No logs found for ${DateFormat('MMM d').format(_selectedDate)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toggle "Online" to start your day',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              _buildTimeline(),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Attendance is automatically logged when you toggle your Online status on the Home screen.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 17, top: 2, bottom: 2),
        height: 30,
        width: 2,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildTimelineNode({
    required bool isFirst,
    required bool isLast,
    required String title,
    required String? time,
    required IconData icon,
    required Color iconColor,
    required bool isOngoing,
    required dynamic log,
    required bool isLogin,
    String? customSubtitle,
    Color? customSubtitleColor,
  }) {
    String subtitle = customSubtitle ?? '';
    Color subtitleColor = customSubtitleColor ?? Colors.grey;

    if (customSubtitle == null) {

    if (isLogin) {
      if (log['login_status'] == 'early' && log['early_login_duration'] != null && log['early_login_duration'].toString().isNotEmpty) {
        subtitle = 'Early Login (${log['early_login_duration']})';
        subtitleColor = Colors.green;
      } else if (log['login_status'] == 'late' && log['late_login_duration'] != null && log['late_login_duration'].toString().isNotEmpty) {
        subtitle = 'Late Login (${log['late_login_duration']} late)';
        subtitleColor = Colors.red;
      }
    } else if (!isOngoing) {
      if (log['logout_status'] == 'early' && log['early_logout_duration'] != null && log['early_logout_duration'].toString().isNotEmpty) {
        subtitle = 'Early Logout (${log['early_logout_duration']})';
        subtitleColor = Colors.red;
      } else if (log['logout_status'] == 'late' && log['late_logout_duration'] != null && log['late_logout_duration'].toString().isNotEmpty) {
        subtitle = 'Overtime (${log['late_logout_duration']})';
        subtitleColor = Colors.green;
      }
    }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isOngoing ? Colors.blue : (iconColor == Colors.red ? Colors.red.shade700 : Colors.black87),
                ),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!isOngoing)
          Text(
            _formatTime(time),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 15,
            ),
          ),
      ],
    );
  }

  Widget _buildTimeline() {
    List<Widget> timelineWidgets = [];
    
    final reversedLogs = _attendanceLogs.reversed.toList();

    String _formatDuration(int totalSeconds) {
      int hours = totalSeconds ~/ 3600;
      int minutes = (totalSeconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }

    for (int i = 0; i < reversedLogs.length; i++) {
      final log = reversedLogs[i];
      final loginTime = log['login_time'];
      final logoutTime = log['logout_time'];
      final isOngoing = logoutTime == null;
      
      // Compute break string for intermediate logins
      String? breakStr;
      if (i > 0 && loginTime != null) {
          final prevLog = reversedLogs[i - 1];
          final prevLogoutTime = prevLog['logout_time'];
          if (prevLogoutTime != null) {
              final prevLogoutDt = DateTime.parse(prevLogoutTime);
              final loginDt = DateTime.parse(loginTime);
              int breakSecs = loginDt.difference(prevLogoutDt).inSeconds;
              if (breakSecs > 0) {
                  breakStr = 'break of ${_formatDuration(breakSecs)}';
              }
          }
      }

      // Compute session string for intermediate logouts
      String? sessionStr;
      if (loginTime != null && logoutTime != null) {
          final loginDt = DateTime.parse(loginTime);
          final logoutDt = DateTime.parse(logoutTime);
          int sessionSecs = logoutDt.difference(loginDt).inSeconds;
          if (sessionSecs > 0) {
              sessionStr = 'session-${i + 1} ${_formatDuration(sessionSecs)}';
          }
      }

      if (i == 0) {
        timelineWidgets.add(_buildTimelineNode(
          isFirst: true,
          isLast: false,
          title: 'First Login of the Day',
          time: loginTime,
          icon: Icons.login_rounded,
          iconColor: Colors.green,
          isOngoing: false,
          log: log,
          isLogin: true,
        ));
      } else {
        timelineWidgets.add(_buildTimelineNode(
          isFirst: false,
          isLast: false,
          title: 'Login',
          time: loginTime,
          icon: Icons.login_rounded,
          iconColor: Colors.green,
          isOngoing: false,
          log: log,
          isLogin: true,
          customSubtitle: breakStr,
          customSubtitleColor: Colors.orange,
        ));
      }
      
      timelineWidgets.add(_buildConnector());

      if (!isOngoing) {
        String logoutReason = log['logout_reason'] ?? 'Logout';
        bool isSuspicious = logoutReason == 'Manual Logout' || logoutReason == 'Offline Timer';
        
        String title = 'Logout';
        if (logoutReason == 'Working Hours Ended') {
            title = 'Working Hours Ended (Auto Logout)';
        } else if (logoutReason == 'Offline Timer' || logoutReason.toLowerCase().contains('timer')) {
            title = 'Timer Logout';
        } else if (logoutReason == 'Manual Logout') {
            title = 'Manual Logout';
        } else {
            title = logoutReason;
        }

        if (i == reversedLogs.length - 1) {
            title = '$title (Last Logout of the Day)';
            timelineWidgets.add(_buildTimelineNode(
              isFirst: false,
              isLast: true,
              title: title,
              time: logoutTime,
              icon: Icons.logout_rounded,
              iconColor: Colors.orange,
              isOngoing: false,
              log: log,
              isLogin: false,
            ));
        } else {
            timelineWidgets.add(_buildTimelineNode(
              isFirst: false,
              isLast: false,
              title: title,
              time: logoutTime,
              icon: Icons.logout_rounded,
              iconColor: isSuspicious ? Colors.red : Colors.orange,
              isOngoing: false,
              log: log,
              isLogin: false,
              customSubtitle: sessionStr,
              customSubtitleColor: Colors.grey.shade600,
            ));
            timelineWidgets.add(_buildConnector());
        }
      } else if (i == reversedLogs.length - 1) {
        timelineWidgets.add(_buildTimelineNode(
          isFirst: false,
          isLast: true,
          title: 'Still Working',
          time: null,
          icon: Icons.sync,
          iconColor: Colors.blue,
          isOngoing: true,
          log: log,
          isLogin: false,
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: timelineWidgets,
      ),
    );
  }

}

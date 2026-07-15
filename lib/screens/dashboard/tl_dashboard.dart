import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import '../dse/lead_list_screen.dart';
import '../dse/lead_form_screen.dart';
import '../dse/feed_screen.dart';
import '../dse/attendance_screen.dart';
import '../tl/user_list_screen.dart';
import '../../providers/break_provider.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import '../auth/login_screen.dart';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/location_service.dart';

class TLDashboard extends StatefulWidget {
  const TLDashboard({super.key});

  @override
  State<TLDashboard> createState() => _TLDashboardState();
}

class _TLDashboardState extends State<TLDashboard> {
  int _selectedIndex = 0;
  bool _isOnline = false;
  bool _isProcessingToggle = false;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    Provider.of<BreakProvider>(context, listen: false).loadFromStorage();
    _checkInitialStatus();
    _setupBackgroundListeners();
  }

  Future<void> _checkInitialStatus() async {
    // Check if offline/break duration exceeded 15 minutes
    const storage = FlutterSecureStorage();
    String? startStr = await storage.read(key: 'break_start_time');
    String? totalSecStr = await storage.read(key: 'total_break_seconds');
    if (startStr != null) {
      int totalSeconds = int.tryParse(totalSecStr ?? '0') ?? 0;
      DateTime startTime = DateTime.fromMillisecondsSinceEpoch(int.parse(startStr));
      totalSeconds += DateTime.now().difference(startTime).inSeconds;
      if (totalSeconds >= 15) {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).logout(isForced: true);
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }
      }
    }

    bool hasNotification = await Permission.notification.isGranted;
    LocationPermission permission = await Geolocator.checkPermission();
    bool hasLocation = permission == LocationPermission.always || permission == LocationPermission.whileInUse;

    if (hasNotification && hasLocation) {
      bool isServiceRunning = await FlutterBackgroundService().isRunning();
      final breakProvider = Provider.of<BreakProvider>(context, listen: false);
      if (!isServiceRunning) {
        // Automatically start the background service and go online!
        await _toggleOnlineStatus(true);
      } else {
        await breakProvider.loadFromStorage();
        if (mounted) {
          setState(() => _isOnline = !breakProvider.isOffline);
        }
      }
    } else {
      // Automatically request permissions and go online!
      await _toggleOnlineStatus(true);
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isProcessingToggle = true);
    final breakProvider = Provider.of<BreakProvider>(context, listen: false);
    
    try {
      if (value) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Location Disabled'),
                content: const Text('Please enable location services to go online.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Geolocator.openLocationSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        if (await Permission.notification.status != PermissionStatus.granted) {
          await Permission.notification.request();
        }
        
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        bool hasNotification = await Permission.notification.isGranted;
        bool hasLocation = permission == LocationPermission.always || permission == LocationPermission.whileInUse;

        if (hasNotification && hasLocation) {
          final isResuming = breakProvider.isOffline;
          if (isResuming) {
            await Future.wait([
              FlutterBackgroundService().startService(),
              breakProvider.stopBreak(),
            ]);
          } else {
            await Future.wait([
              _locationService.markAttendance('login'),
              FlutterBackgroundService().startService(),
              breakProvider.stopBreak(),
            ]);
          }
          FlutterBackgroundService().invoke('updateUserStatus', {'isOnline': true});
          
          if (mounted) setState(() => _isOnline = true);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please grant all permissions to go Online')),
            );
          }
        }
      } else {
        await breakProvider.startBreak();
        FlutterBackgroundService().invoke('updateUserStatus', {'isOnline': false});
        
        if (mounted) setState(() => _isOnline = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingToggle = false);
      }
    }
  }

  void _setupBackgroundListeners() {
    FlutterBackgroundService().on('locationOff').listen((event) {
      // SnackBar warning disabled
    });

    FlutterBackgroundService().on('forceLogout').listen((event) {
      if (!mounted) return;
      Provider.of<AuthProvider>(context, listen: false).logout(isForced: true);
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  List<Widget> get _widgetOptions => [
    FeedScreen(isOnline: _isOnline),
    const LeadListScreen(),
    const AttendanceScreen(),
    const UserListScreen(showAppBar: false),
    const ProfileScreen(showAppBar: false),
  ];



  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon) {
    final isActive = _selectedIndex == index;
    final size = isActive ? 32.0 : 26.0;

    Widget iconWidget;
    if (index == 4) {
      final auth = Provider.of<AuthProvider>(context);
      final photoPath = auth.profilePhotoPath;
      final file = photoPath != null && photoPath.isNotEmpty ? File(photoPath) : null;
      final hasPhoto = file != null && file.existsSync();
      if (hasPhoto) {
        iconWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
              width: 1.5,
            ),
          ),
          child: CircleAvatar(
            radius: (size / 2) - 1,
            backgroundImage: FileImage(file),
          ),
        );
      } else {
        iconWidget = Icon(
          isActive ? selectedIcon : unselectedIcon,
          color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
          size: size,
        );
      }
    } else {
      iconWidget = Icon(
        isActive ? selectedIcon : unselectedIcon,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
        size: size,
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isActive ? 8 : 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF3F51B5).withOpacity(0.25) : Colors.transparent,
            ),
            child: iconWidget,
          ),
          const SizedBox(height: 3),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isActive ? 1.0 : 0.0,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3F51B5), // Core Theme Indigo Active Dot!
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      extendBodyBehindAppBar: _selectedIndex == 0,
      extendBody: true,
      appBar: _selectedIndex == 0 
        ? AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 135,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Center(
                child: GestureDetector(
                  onTap: _isProcessingToggle ? null : () => _toggleOnlineStatus(!_isOnline),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: 115,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline ? const Color(0xFF4CAF50) : Colors.grey).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Background Text
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          alignment: _isOnline ? Alignment.centerLeft : Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: _isOnline ? 12 : 0,
                              right: _isOnline ? 0 : 10,
                            ),
                            child: Text(
                              _isOnline ? 'ONLINE' : 'OFFLINE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                        // Sliding Knob
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isProcessingToggle
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3F51B5)),
                                        ),
                                      )
                                    : Icon(
                                        _isOnline ? Icons.location_on : Icons.location_off,
                                        size: 16,
                                        color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : AppBar(
            title: Text(
              _selectedIndex == 1 
                ? 'My Leads and Enquiries' 
                : _selectedIndex == 2 
                  ? 'TL Attendance' 
                  : _selectedIndex == 3
                    ? 'My Team'
                    : 'My Profile'
            ),
          ),
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF14193F), // Premium dark theme matching midnight blue
                Color(0xFF0A0D25), // Blue-black dark theme
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: const Color(0xFF3F51B5).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14193F).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded),
              _buildNavItem(1, Icons.people_alt_outlined, Icons.people_alt_rounded),
              _buildNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month_rounded),
              _buildNavItem(3, Icons.group_outlined, Icons.group_rounded),
              _buildNavItem(4, Icons.account_circle_outlined, Icons.account_circle_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

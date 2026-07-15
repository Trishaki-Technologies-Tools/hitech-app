import 'dart:async';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // 1. Create the Notification Channel explicitly for Android 14
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'location_tracking_channel_v2', // id
      'Hitech Pragati Real-time Tracking', // title
      description: 'Used for workforce monitoring and attendance verification', // description
      importance: Importance.low, 
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking_channel_v2',
        initialNotificationTitle: 'Hitech Pragati is Online',
        initialNotificationContent: 'Your location is being monitored for attendance.',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // 1. For Android 14+, we MUST call setAsForegroundService immediately 
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    try {
      final ApiService apiService = ApiService();
      const storage = FlutterSecureStorage();
      Timer? trackingTimer;
      bool userWantsToBeOnline = true;

      service.on('stopService').listen((event) {
        trackingTimer?.cancel();
        service.stopSelf();
      });

      service.on('updateUserStatus').listen((event) {
        if (event != null) {
          userWantsToBeOnline = event['isOnline'] ?? true;
        }
      });

      trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          final now = DateTime.now();

          bool locationEnabled = await Geolocator.isLocationServiceEnabled();
          LocationPermission permission = await Geolocator.checkPermission();
          bool hasPermission = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
          
          bool isActuallyTracking = userWantsToBeOnline && locationEnabled && hasPermission;

          if (!isActuallyTracking) {
            // User is offline (either because they clicked OFFLINE, or because GPS/permission is off)
            String? totalSecStr = await storage.read(key: 'total_break_seconds');
            String? startStr = await storage.read(key: 'break_start_time');
            
            int totalSeconds = int.tryParse(totalSecStr ?? '0') ?? 0;
            if (startStr != null) {
              DateTime startTime = DateTime.fromMillisecondsSinceEpoch(int.parse(startStr));
              totalSeconds += now.difference(startTime).inSeconds;
            } else {
              // Start tracking offline/GPS-disabled duration immediately
              await storage.write(key: 'break_start_time', value: now.millisecondsSinceEpoch.toString());
              startStr = now.millisecondsSinceEpoch.toString();
            }

            int totalMinutes = totalSeconds ~/ 60;

            service.invoke('locationOff', {
              'minutesOff': totalMinutes,
              'remaining': ((15 - totalSeconds) > 0 ? (15 - totalSeconds) : 0)
            });

            if (totalSeconds >= 15) {
              final logoutTime = now.subtract(Duration(seconds: totalSeconds));
              final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(logoutTime);
              
              await apiService.post('mark_attendance.php', {
                'action': 'logout',
                'latitude': 0,
                'longitude': 0,
                'logout_time': formattedTime,
                'custom_time': formattedTime,
                'timestamp': formattedTime,
                'backdate_minutes': totalSeconds ~/ 60,
              });
              await apiService.get('logout_user.php?force=1');
              await storage.write(key: 'total_break_seconds', value: '0');
              await storage.delete(key: 'break_start_time');
              await storage.write(key: 'otp_required', value: 'true');
              
              service.invoke('forceLogout');
              trackingTimer?.cancel();
              service.stopSelf();
            }
          } else {
            // Online and successfully tracking - reset break state
            await storage.write(key: 'total_break_seconds', value: '0');
            await storage.delete(key: 'break_start_time');
          }

          if (isActuallyTracking) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 15),
            );
            await apiService.post('update_location.php', {
              'latitude': position.latitude,
              'longitude': position.longitude,
            });
          }
        } catch (e) {
          // Silent catch
        }
      });
    } catch (e) {
      // Global onStart fail safe
    }
  }
}

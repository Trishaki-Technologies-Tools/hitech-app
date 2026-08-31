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
      StreamSubscription<Position>? positionStream;
      List<Map<String, dynamic>> locationBatch = [];

      void startLocationStream() async {
        if (positionStream != null) return;
        
        // Instant sync on going online so the Web Dashboard updates immediately
        try {
          Position initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          await apiService.post('tracking.php?type=location', {
            'action': 'sync',
            'locations': [{
              'lat': initialPos.latitude,
              'lng': initialPos.longitude,
              'accuracy': initialPos.accuracy,
              'speed': initialPos.speed,
              'bearing': initialPos.heading,
              'timestamp': initialPos.timestamp != null ? initialPos.timestamp!.toIso8601String() : DateTime.now().toIso8601String(),
            }],
          });
        } catch (_) {}

        late final LocationSettings locationSettings;
        if (Platform.isIOS) {
          locationSettings = AppleLocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );
        } else if (Platform.isAndroid) {
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
            intervalDuration: const Duration(seconds: 10),
          );
        } else {
          locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          );
        }

        positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) async {
          if (position.accuracy > 300) return; // Ignore wildly inaccurate GPS data

          locationBatch.add({
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy': position.accuracy,
            'speed': position.speed,
            'bearing': position.heading,
            'timestamp': position.timestamp != null ? position.timestamp!.toIso8601String() : DateTime.now().toIso8601String(),
          });

          // Sync in batches of 1 (real-time enough due to distance filter) or more if offline
          try {
            await apiService.post('tracking.php?type=location', {
              'action': 'sync',
              'locations': locationBatch,
            });
            locationBatch.clear(); // Clear on success
          } catch (e) {
            // Keep in batch if network fails
          }
        });
      }

      void stopLocationStream() {
        positionStream?.cancel();
        positionStream = null;
      }

      service.on('stopService').listen((event) {
        trackingTimer?.cancel();
        stopLocationStream();
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
            stopLocationStream();
            
            // User is offline (either because they clicked OFFLINE, or because GPS/permission is off)
            
            String loginStr = await storage.read(key: 'office_login_time') ?? '09:00';
            String logoutStr = await storage.read(key: 'office_logout_time') ?? '18:00';
            final currentStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            
            bool withinHours = false;
            if (loginStr.compareTo(logoutStr) <= 0) {
              withinHours = (currentStr.compareTo(loginStr) >= 0 && currentStr.compareTo(logoutStr) <= 0);
            } else {
              withinHours = (currentStr.compareTo(loginStr) >= 0 || currentStr.compareTo(logoutStr) <= 0);
            }

            if (!withinHours) {
              // Outside working hours -> no forced timer, no OTP locks
              await storage.delete(key: 'break_start_time');
              service.invoke('locationOff', {
                'minutesOff': 0,
                'remaining': 0,
                'hideTimer': true
              });
              return;
            }

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
              'remaining': ((15 - totalSeconds) > 0 ? (15 - totalSeconds) : 0),
              'hideTimer': false
            });

            if (totalSeconds >= 15) {
              final logoutTime = now.subtract(Duration(seconds: totalSeconds));
              final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(logoutTime);
              await apiService.post('tracking.php?type=location', {'action': 'end_trip'});
              
              await apiService.post('mark_attendance.php', {
                'action': 'logout',
                'logout_reason': 'Offline Timer',
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
            startLocationStream(); // Ensure stream is running
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

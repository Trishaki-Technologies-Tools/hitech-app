import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/break_provider.dart';
import '../../services/location_service.dart';
import 'lead_form_screen.dart';
import '../auth/login_screen.dart';

class FeedScreen extends StatefulWidget {
  final bool isOnline;
  final VoidCallback? onGoOnline;
  const FeedScreen({super.key, required this.isOnline, this.onGoOnline});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  LatLng? _currentPosition;
  bool _isLoading = true;

  // UX Fix variables for Disabled Location
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _isLocationDisabled = false;
  Timer? _gpsWarningTimer;
  int _gpsWarningSeconds = 15; // Warning countdown duration before auto-logout
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _determinePosition();

    // Listen dynamically to device GPS status changes
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((status) {
      _determinePosition();
    });
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline != oldWidget.isOnline) {
      _determinePosition();
    }
  }

  @override
  void dispose() {
    _serviceStatusSubscription?.cancel();
    _gpsWarningTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Auto-logout countdown warning timer when GPS is turned off
  void _startGpsWarningTimer() {
    _gpsWarningTimer?.cancel();
    setState(() {
      _isLocationDisabled = true;
      _gpsWarningSeconds = 15; // Start at 15 seconds
    });
    _updateMarkers();

    _gpsWarningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_gpsWarningSeconds > 0) {
        setState(() {
          _gpsWarningSeconds--;
        });
      } else {
        _gpsWarningTimer?.cancel();
        // Force log the user out due to disabled location tracking
        Provider.of<AuthProvider>(context, listen: false).logout(isForced: true);
        
        // Root redirect to LoginScreen immediately
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  // Stops countdown when GPS is re-enabled
  void _stopGpsWarningTimer() {
    _gpsWarningTimer?.cancel();
    setState(() {
      _isLocationDisabled = false;
      _gpsWarningSeconds = 15;
    });
    _updateMarkers();
  }

  // Update map markers dynamically based on GPS connectivity status
  void _updateMarkers() {
    if (_currentPosition == null) return;
    setState(() {
      final isOfflineMode = !widget.isOnline;
      _markers = {
        Marker(
          markerId: const MarkerId('active_dse_location'),
          position: _currentPosition!,
          infoWindow: InfoWindow(
            title: isOfflineMode 
                ? 'Last Known Location (Offline)' 
                : (_isLocationDisabled ? 'Last Known Location' : 'Current Location'),
            snippet: isOfflineMode
                ? 'Tracking paused'
                : (_isLocationDisabled ? 'GPS signal lost / disabled' : 'Active live tracking'),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isOfflineMode
                ? BitmapDescriptor.hueRed
                : (_isLocationDisabled ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueBlue),
          ),
        ),
      };
    });
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      // If GPS is disabled by the user
      if (!serviceEnabled) {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (mounted) {
          setState(() {
            // Center map on last known coordinates, or default to custom showroom coordinates
            _currentPosition = lastKnown != null 
                ? LatLng(lastKnown.latitude, lastKnown.longitude)
                : const LatLng(15.8259444, 74.5608169);
            _isLoading = false;
          });
          _startGpsWarningTimer();
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
          );
        }
        return;
      }

      // If GPS is active, stop warnings
      _stopGpsWarningTimer();

      // 1. Instantly use last known position so map loads instantly
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
          _isLoading = false;
        });
        _updateMarkers();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
        );
      }

      // 2. Fetch high accuracy position in the background
      Position position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _updateMarkers();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_currentPosition == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition ?? const LatLng(0, 0),
                  zoom: 15.0,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (_currentPosition != null) {
                    _mapController?.moveCamera(
                      CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
                    );
                  }
                },
                markers: _markers,
                myLocationEnabled: !_isLocationDisabled, // Disable blue dot in missing GPS state
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
              ),

          // GPS Disabled Timer Warning Overlay Banner
          if (_isLocationDisabled && widget.isOnline)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade300.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.gps_off_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GPS Location Service Disabled',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Please enable location services immediately to continue your online session.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Logout in: ${(_gpsWarningSeconds ~/ 60).toString().padLeft(2, '0')}:${(_gpsWarningSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Geolocator.openLocationSettings();
                              },
                              icon: const Icon(Icons.settings, size: 14),
                              label: const Text(
                                'Enable GPS',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red.shade900,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Offline Bottom Card Drawer (Blocks bottom navigation since bottom nav bar is hidden)
          if (!widget.isOnline)
            Consumer<BreakProvider>(
              builder: (context, breakProvider, child) {
                if (breakProvider.isOffline) {
                  int remaining = 15 - breakProvider.currentSessionSeconds;
                  if (remaining < 0) remaining = 0;
                  int mins = remaining ~/ 60;
                  int secs = remaining % 60;
                  String countdownStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(36),
                          topRight: Radius.circular(36),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            spreadRadius: 8,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(
                        top: 14,
                        left: 28,
                        right: 28,
                        bottom: 36,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sleek top drawer bar
                          Container(
                            width: 42,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.wifi_off_rounded,
                                  color: Colors.red.shade800,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'You are offline',
                                      style: TextStyle(
                                        color: Colors.grey.shade900,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your tracking has been paused.',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Go online before $countdownStr or else your ID will be logged out.',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          if (widget.onGoOnline != null)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: widget.onGoOnline,
                                icon: const Icon(Icons.flash_on_rounded, size: 18),
                                label: const Text(
                                  'Go Online',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3F51B5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF3F51B5).withOpacity(0.3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
      floatingActionButton: widget.isOnline 
        ? Padding(
            padding: const EdgeInsets.only(bottom: 105.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeadFormScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Enquiry'),
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
            ),
          )
        : null,
    );
  }
}

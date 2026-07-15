import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';
import '../dashboard/tl_dashboard.dart';
import '../dashboard/dse_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();
    final startTime = DateTime.now();
    
    // Wait until AuthProvider has finished loading user data from storage
    int attempts = 0;
    while (!auth.isInitialized && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }

    // Luxury-grade minimum 2.5 second splash display
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < 2500) {
      await Future.delayed(Duration(milliseconds: 2500 - elapsed));
    }

    if (!mounted) return;

    if (auth.isAuthenticated) {
      final role = auth.user!.role.toLowerCase();
      if (role != 'tl' && role != 'dse') {
        await auth.logout(isForced: true);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      // Verify with server if we are outside work hours (Disabled to keep users logged in outside working hours)
      /*
      try {
        final response = await apiService.get('settings.php');
          if (response['status'] == 'success') {
            final settings = response['settings'];
            if (settings != null) {
              final loginStr = settings['login_time'] as String? ?? '09:00';
              final logoutStr = settings['logout_time'] as String? ?? '18:00';

              final now = DateTime.now();
              final currentStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

              bool withinHours = false;
              if (loginStr.compareTo(logoutStr) <= 0) {
                withinHours = (currentStr.compareTo(loginStr) >= 0 && currentStr.compareTo(logoutStr) <= 0);
              } else {
                withinHours = (currentStr.compareTo(loginStr) >= 0 || currentStr.compareTo(logoutStr) <= 0);
              }

              if (!withinHours) {
                await auth.logout(isForced: true);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Access blocked: outside allowed working hours ($loginStr - $logoutStr)'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('Startup timing verification skipped (offline or network error): $e');
        }
      */

      _navigateBasedOnRole(auth.user!.role);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _navigateBasedOnRole(String role) {
    Widget nextScreen;
    switch (role.toLowerCase()) {
      case 'tl':
        nextScreen = const TLDashboard();
        break;
      case 'dse':
        nextScreen = const DSEDashboard();
        break;
      default:
        nextScreen = const LoginScreen();
    }
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3F51B5), // Deep indigo
              Color(0xFF283593), // Darker midnight indigo for premium depth
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // App Icon / Logo with slight glowing backdrop
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // App Name
              const Text(
                'Hitech Pragati',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              
              // Slogan / Quote Symmetrical Slogan Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  'Driven by Goals. Powered by Performance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 0.5,
                    height: 1.4,
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Custom styled material spinner and loading cue
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing assistant...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

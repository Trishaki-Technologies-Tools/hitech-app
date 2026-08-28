import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Elastic pop for the logo
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );

    // Fade and slide for the text
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic)),
    );

    _controller.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      // Fetch office hours to use for timer logic later
      try {
        final response = await apiService.get('settings.php');
        if (response['status'] == 'success') {
          final settings = response['settings'];
          if (settings != null) {
            final loginStr = settings['login_time'] as String? ?? '09:00';
            final logoutStr = settings['logout_time'] as String? ?? '18:00';
            
            await const FlutterSecureStorage().write(key: 'office_login_time', value: loginStr);
            await const FlutterSecureStorage().write(key: 'office_logout_time', value: logoutStr);
          }
        }
      } catch (e) {
        // Silently ignore if offline
      }
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3F51B5), // Lighter Slate Blue at top
              Color(0xFF1A237E), // Deep primary Slate Blue at bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // App Icon / Logo with elastic pop animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
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
              ),
              const SizedBox(height: 32),
              
              // Animated Text Block
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
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
                    ],
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Animated Loader
              FadeTransition(
                opacity: _fadeAnimation,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../dashboard/tl_dashboard.dart';
import '../dashboard/dse_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _showOtpField = false;
  final _otpController = TextEditingController();

  bool _permissionsGranted = false;
  bool _isCheckingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() { _isCheckingPermissions = false; _permissionsGranted = false; });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) setState(() { _isCheckingPermissions = false; _permissionsGranted = false; });
    } else {
      if (mounted) setState(() { _isCheckingPermissions = false; _permissionsGranted = true; });
    }
  }

  void _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final otp = _otpController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_showOtpField && otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manager OTP is required')),
      );
      return;
    }

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.login(phone, password, otp: _showOtpField ? otp : null);
      
      try {
        final apiService = ApiService();
        final response = await apiService.get('settings.php');
        if (response['status'] == 'success') {
          final settings = response['settings'];
          if (settings != null) {
            await const FlutterSecureStorage().write(key: 'office_login_time', value: settings['login_time'] ?? '09:00');
            await const FlutterSecureStorage().write(key: 'office_logout_time', value: settings['logout_time'] ?? '18:00');
          }
        }
      } catch (e) {
        // Ignore if failed to fetch
      }

      if (!mounted) return;
      _navigateBasedOnRole(auth.user!.role);
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      
      if (errorMsg.contains('OTP is required')) {
        setState(() => _showOtpField = true);
        return;
      }
      
      if (errorMsg.toLowerCase().contains('invalid manager otp') || errorMsg.toLowerCase().contains('invalid otp')) {
        _showErrorDialog('Wrong OTP', 'The OTP you entered is incorrect.\nPlease verify with your manager and try again.', Icons.error_outline, Colors.red);
      } else if (errorMsg.toLowerCase().contains('invalid credentials') || errorMsg.toLowerCase().contains('wrong')) {
        _showErrorDialog('Login Failed', 'Wrong credentials. Please check your details and try again.', Icons.error_outline, Colors.red);
      } else if (errorMsg.toLowerCase().contains('another device')) {
        _showErrorDialog('Invalid Device', 'This ID is already logged in on another device.\n\nPlease use the same device for login.', Icons.phonelink_erase, Colors.orange);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    }
  }

  void _showErrorDialog(String title, String content, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(content, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        return;
    }
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    final primaryColor = const Color(0xFF3F51B5); // Slate Blue theme
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: primaryColor,
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                // Top Slate Blue Header Area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Hitech Pragati',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to continue your work.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // White Container with Curved Top
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (!isKeyboardOpen)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Image.asset(
                        'assets/icon/login_vector.png',
                        height: 180, // Reduced fixed height to avoid pushing constraints
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  const Spacer(),

                // Remaining Screen Area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 18, letterSpacing: 1.2, fontWeight: FontWeight.w500),
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            hintText: 'Enter your phone number',
                            prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24), // Gap between fields
                        
                        const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(fontSize: 18, letterSpacing: 1.2, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter your Password',
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                          ),
                        ),

                        if (_showOtpField) ...[
                          const SizedBox(height: 24),
                          const Text('Manager OTP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 20, letterSpacing: 2.0, fontWeight: FontWeight.bold),
                            maxLength: 6,
                            decoration: InputDecoration(
                              hintText: 'Enter 6-digit OTP',
                              prefixIcon: const Icon(Icons.security, color: Colors.grey),
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20), // Gap before the swipe button
                        
                        if (_isCheckingPermissions)
                          const Center(child: CircularProgressIndicator())
                        else if (!_permissionsGranted)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.location_off, color: Colors.red, size: 32),
                                const SizedBox(height: 8),
                                const Text(
                                  'Location Permissions Required',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Please enable location services and permissions in your device settings to log in.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  onPressed: _checkAndRequestPermissions,
                                  child: const Text('Check Again'),
                                )
                              ],
                            ),
                          )
                        else
                          // Swipe to Login Button at extreme bottom
                          SwipeToLoginButton(
                            isLoading: isLoading,
                            onSwipe: _login,
                            color: primaryColor,
                          ),
                        
                        const SizedBox(height: 20), // Spacing from the bottom edge of the screen
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Swipe to Login Button
class SwipeToLoginButton extends StatefulWidget {
  final VoidCallback onSwipe;
  final bool isLoading;
  final Color color;

  const SwipeToLoginButton({
    super.key,
    required this.onSwipe,
    this.isLoading = false,
    required this.color,
  });

  @override
  State<SwipeToLoginButton> createState() => _SwipeToLoginButtonState();
}

class _SwipeToLoginButtonState extends State<SwipeToLoginButton> {
  double _position = 5.0; // Start with 5px padding on left
  bool _isSwiped = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxSlide = constraints.maxWidth - 55; // 50 (width) + 5 (padding)
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Swipe to Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                if (!widget.isLoading)
                  Positioned(
                    left: _position,
                    top: 5,
                    bottom: 5,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _position += details.delta.dx;
                          if (_position < 5.0) _position = 5.0;
                          if (_position > maxSlide) _position = maxSlide;
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        if (_position > maxSlide * 0.8) {
                          setState(() {
                            _position = maxSlide;
                            _isSwiped = true;
                          });
                          widget.onSwipe();
                          // Reset slider after a delay
                          Future.delayed(const Duration(milliseconds: 1000), () {
                            if (mounted) {
                              setState(() {
                                _position = 5.0;
                                _isSwiped = false;
                              });
                            }
                          });
                        } else {
                          setState(() {
                            _position = 5.0;
                          });
                        }
                      },
                      child: Container(
                        width: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(2, 0),
                            )
                          ]
                        ),
                        child: Icon(Icons.keyboard_double_arrow_right, color: widget.color),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

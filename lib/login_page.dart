import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'location_service.dart';

final _logger = Logger('LoginPage');

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isBiometricAuthSuccessful = false;
  bool _obscureText = true;
  int _biometricAttempts = 0;
  int _nipLoginAttempts = 0;
  final int _maxBiometricAttempts = 3;
  final int _maxNipLoginAttempts = 5;
  bool _isLoggingIn = false;
  bool _rememberNip = false;

  final TextEditingController _nipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  Timer? _sessionTimer;
  final int _sessionTimeoutSeconds = 300; // 5 menit

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _setupLogging();
    _loadSavedNip();
    _authenticateWithBiometrics();
    _setupAnimation();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController.forward();
  }

  void _setupLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _nipController.dispose();
    _passwordController.dispose();
    _sessionTimer?.cancel();
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedNip() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNip = prefs.getString('saved_nip');
    if (savedNip != null) {
      setState(() {
        _nipController.text = savedNip;
        _rememberNip = true;
      });
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(seconds: _sessionTimeoutSeconds), () {
      _logout();
    });
  }

  void _logout() {
    setState(() {
      _isBiometricAuthSuccessful = false;
      _passwordController.clear();
      _errorMessage = 'Sesi Anda telah berakhir. Silakan login kembali.';
    });
    _logger.info('Pengguna logout karena sesi berakhir');
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_biometricAttempts >= _maxBiometricAttempts) {
      setState(() {
        _errorMessage =
            'Batas maksimum percobaan Face ID telah tercapai. Silakan hubungi administrator.';
      });
      _logger.warning('Batas maksimum percobaan Face ID tercapai');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan wajah Anda untuk login',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _isBiometricAuthSuccessful = authenticated;
        if (!authenticated) {
          _biometricAttempts++;
          _errorMessage = _biometricAttempts < _maxBiometricAttempts
              ? 'Autentikasi Face ID gagal. Silakan coba lagi. (Percobaan $_biometricAttempts/$_maxBiometricAttempts)'
              : 'Batas maksimum percobaan Face ID telah tercapai. Silakan hubungi administrator.';
          _logger.warning(
              'Autentikasi Face ID gagal. Percobaan: $_biometricAttempts');
        } else {
          _startSessionTimer();
          _logger.info('Autentikasi Face ID berhasil');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat autentikasi: $e';
      });
      _logger.severe('Kesalahan saat autentikasi biometrik: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
      });
    }
    _animationController.forward();
  }

  bool _validateInputs() {
    if (_nipController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'NIP dan password harus diisi.';
      });
      _logger.warning('Upaya login dengan input kosong');
      return false;
    }
    return true;
  }

  Future<void> _loginWithNip() async {
    if (!mounted) return;

    if (!_isBiometricAuthSuccessful) {
      setState(() {
        _errorMessage =
            'Autentikasi Face ID diperlukan sebelum login dengan NIP.';
      });
      _logger.warning('Upaya login tanpa autentikasi Face ID');
      return;
    }

    if (!_validateInputs()) return;

    if (_nipLoginAttempts >= _maxNipLoginAttempts) {
      setState(() {
        _errorMessage =
            'Batas maksimum percobaan login NIP telah tercapai. Silakan hubungi administrator.';
      });
      _logger.warning('Batas maksimum percobaan login NIP tercapai');
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _errorMessage = '';
    });

    final nip = _nipController.text;
    final password = _passwordController.text;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithNip(nip, password);

      if (!mounted) return;

      if (user != null) {
        LocationService locationService = LocationService();
        bool isWithinAllowedLocation =
            await locationService.isWithinAllowedLocation();

        if (!mounted) return;

        if (isWithinAllowedLocation) {
          _passwordController.clear();
          if (_rememberNip) {
            _saveNip(nip);
          } else {
            _clearSavedNip();
          }
          _logger.info('Login berhasil untuk NIP: $nip');
          Navigator.pushReplacementNamed(context, '/main');
        } else {
          setState(() {
            _errorMessage =
                'Anda berada di luar area yang diizinkan. Lokasi yang diizinkan. Silakan pindah ke lokasi yang telah ditentukan dan coba lagi.';
          });
          _logger
              .warning('Login gagal: Lokasi tidak diizinkan untuk NIP: $nip');
        }
      } else {
        setState(() {
          _nipLoginAttempts++;
          _errorMessage =
              'NIP atau password tidak valid. Silakan periksa kembali dan coba lagi. (Percobaan $_nipLoginAttempts/$_maxNipLoginAttempts)';
        });
        _logger.warning(
            'Login gagal: NIP atau password tidak valid. Percobaan: $_nipLoginAttempts');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat login: $e';
      });
      _logger.severe('Kesalahan saat login: $e');
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }

  Future<void> _saveNip(String nip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_nip', nip);
    _logger.info('NIP disimpan untuk fitur "Ingat NIP"');
  }

  Future<void> _clearSavedNip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_nip');
    _logger.info('NIP tersimpan dihapus');
  }

  // ... (lanjut ke bagian kedua)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogoSection(),
            const SizedBox(height: 20),
            _buildAuthenticationStatus(),
            if (_isBiometricAuthSuccessful) _buildLoginForm(),
            if (_errorMessage.isNotEmpty) _buildErrorMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/bea_cukai.png',
            width: 90,
            height: 90,
          ),
        ),
        const SizedBox(width: 20),
        Container(
          width: 3,
          height: 40,
          color: Colors.black,
        ),
        const SizedBox(width: 20),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/kemenkeu.png',
            width: 90,
            height: 90,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthenticationStatus() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _isAuthenticating
          ? const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Melakukan autentikasi Face ID...'),
              ],
            )
          : _isBiometricAuthSuccessful
              ? const Text(
                  'Autentikasi Face ID berhasil. Silakan lanjutkan dengan memasukkan NIP dan Password.',
                  style: TextStyle(color: Colors.green),
                  textAlign: TextAlign.center,
                )
              : Column(
                  children: [
                    const Text(
                      'Autentikasi Face ID diperlukan untuk melanjutkan.',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _biometricAttempts < _maxBiometricAttempts
                          ? _authenticateWithBiometrics
                          : null,
                      child: const Text('Coba Face ID Lagi'),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLoginForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextField(
            controller: _nipController,
            decoration: const InputDecoration(
              labelText: 'NIP',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
            obscureText: _obscureText,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _rememberNip,
                onChanged: (bool? value) {
                  setState(() {
                    _rememberNip = value ?? false;
                  });
                },
              ),
              const Text('Ingat NIP'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoggingIn ? null : _loginWithNip,
            child: _isLoggingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Login dengan NIP'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              // TODO: Implementasi fungsi lupa password
              _showForgotPasswordDialog();
            },
            child: const Text('Lupa Password?'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        _errorMessage,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Lupa Password'),
          content: const Text(
              'Silakan hubungi administrator untuk mereset password Anda.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Tutup'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

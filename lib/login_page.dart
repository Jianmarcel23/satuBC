import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';
import 'location_service.dart'; // Import LocationService

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isAuthorized = false; // Ini untuk melacak apakah Face ID berhasil
  bool _obscureText = true;

  final TextEditingController _nipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isAuthenticating = true;
    });

    bool authenticated = false;

    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your face to login',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        // Jika berhasil, set _isAuthorized ke true tapi tetap di halaman login
        setState(() {
          _isAuthorized = true;
        });
      } else {
        setState(() {
          _isAuthorized =
              false; // Set authorized to false if authentication fails
        });
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        _isAuthenticating = false; // Mengatur status autentikasi ke false
      });
    }
  }

  Future<void> _loginWithNip() async {
    final nip = _nipController.text;
    final password = _passwordController.text;

    final user = await context.read<AuthService>().signInWithNip(nip, password);

    if (user != null) {
      // Menggunakan LocationService untuk mendapatkan lokasi
      LocationService locationService = LocationService();
      bool isWithinAllowedLocation =
          await locationService.isWithinAllowedLocation();

      if (isWithinAllowedLocation) {
        // Jika dalam lokasi yang diizinkan, navigasi ke halaman utama
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        setState(() {
          _errorMessage =
              'Lokasi tidak sesuai. Silakan coba lagi di lokasi yang diizinkan.';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'NIP atau password tidak valid';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
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
            ),
            const SizedBox(height: 20),
            if (_isAuthenticating) const CircularProgressIndicator(),
            if (!_isAuthenticating) ...[
              if (_isAuthorized) ...[
                const Text(
                  'Autentikasi Face ID berhasil. Silakan lanjutkan dengan memasukkan NIP dan Password.',
                  style: TextStyle(color: Colors.green),
                ),
              ] else ...[
                const Text(
                  'Autentikasi Face ID gagal. Silakan masukkan kredensial Anda.',
                  style: TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _nipController,
                decoration: const InputDecoration(labelText: 'NIP'),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loginWithNip,
                child: const Text('Login dengan NIP'),
              ),
            ],
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

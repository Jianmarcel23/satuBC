import 'package:flutter/material.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0)).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));

    _fadeController.forward();

    Future.delayed(const Duration(seconds: 2), () {
      _slideController.forward().then((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo('assets/bea_cukai.png'),
                const SizedBox(width: 20),
                Container(width: 3, height: 40, color: Colors.black),
                const SizedBox(width: 20),
                _buildLogo('assets/kemenkeu.png'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(String assetPath) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.asset(assetPath, width: 90, height: 90),
    );
  }
}

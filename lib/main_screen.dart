import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'attendance_service.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'qr_scan_page.dart';
import 'profile_page.dart';
import 'attendance_history_page.dart';
import 'main.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final AttendanceService _attendanceService;
  late final AuthService _authService;
  late final LocationService _locationService;
  String? _employeeId;
  String? _nip;
  bool _isLocationAllowed = false;
  List<Map<String, dynamic>> _timeCard = [];
  Timer? _refreshTimer;
  bool _isDarkMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => _refreshData());
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _checkLocation(),
        _loadTodayAttendance(),
      ]);
    } catch (e) {
      if (mounted) {
        _showErrorNotification(AppLocalizations.of(context)!.refreshDataError);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeServices() async {
    _attendanceService = AttendanceService(AuthService());
    _authService = Provider.of<AuthService>(context, listen: false);
    _locationService = LocationService();

    await _fetchCurrentUser();
    if (_employeeId != null) {
      await _checkAndRequestPermissions();
      await _refreshData();
    }
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData != null) {
        setState(() {
          _nip = userData['nip'];
          _employeeId = userData['id'];
        });
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorNotification(
            AppLocalizations.of(context)!.fetchUserDataError);
      }
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    if (locationPermission == LocationPermission.deniedForever) {
      if (mounted) {
        _showPermissionError(
            AppLocalizations.of(context)!.locationPermissionDeniedForever);
      }
      openAppSettings();
    } else if (locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse) {
      await _checkLocation();
    } else {
      if (mounted) {
        _showPermissionError(
            AppLocalizations.of(context)!.locationPermissionRequired);
      }
    }

    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<void> _checkLocation() async {
    _isLocationAllowed =
        await _locationService.isWithinAllowedLocation(radius: 200.0);
    if (mounted) setState(() {});
  }

  Future<void> _loadTodayAttendance() async {
    if (_employeeId != null) {
      try {
        _timeCard = await _attendanceService.getAttendanceForDate(
            _employeeId!, DateTime.now());
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          _showErrorNotification(
              AppLocalizations.of(context)!.loadAttendanceError);
        }
      }
    }
  }

  void _showErrorNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPermissionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _navigateToQRCodeScanner() async {
    if (!_isLocationAllowed) {
      _showLocationError();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScanPage(
          onAttendanceMarked: (nip, activity, timestamp) async {
            await _refreshData();
          },
        ),
      ),
    );

    if (result == true) {
      await _refreshData();
    }
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.notInAllowedLocation),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(employeeId: _employeeId!),
      ),
    );
  }

  void _navigateToAttendanceHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AttendanceHistoryPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: _buildAppBar(),
        drawer: _buildDrawer(),
        body: _isLoading ? _buildLoadingIndicator() : _buildBody(),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      color: Colors.blueAccent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.welcome(_nip ?? ''),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.employeeTitle,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _isLocationAllowed ? Icons.location_on : Icons.location_off,
                  color: _isLocationAllowed ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isLocationAllowed
                      ? AppLocalizations.of(context)!.inAllowedLocation
                      : AppLocalizations.of(context)!.notInAllowedLocation,
                  style: TextStyle(
                    color: _isLocationAllowed ? Colors.white : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(AppLocalizations.of(context)!.appTitle),
      backgroundColor: Colors.blueAccent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            _authService.signOut();
            Navigator.pushReplacementNamed(context, '/');
          },
          tooltip: AppLocalizations.of(context)!.logout,
        ),
        Switch(
          value: _isDarkMode,
          onChanged: (value) => setState(() => _isDarkMode = value),
          activeColor: Colors.white,
          inactiveThumbColor: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_nip ?? ''),
              accountEmail:
                  Text(AppLocalizations.of(context)?.employeeTitle ?? ''),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.blueAccent),
              ),
              decoration: const BoxDecoration(color: Colors.blueAccent),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(AppLocalizations.of(context)?.profile ?? 'Profile'),
              onTap: _navigateToProfile,
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(AppLocalizations.of(context)?.attendanceHistory ??
                  'Attendance History'),
              onTap: _navigateToAttendanceHistory,
            ),
            const LanguageSelectionWidget(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(AppLocalizations.of(context)?.logout ?? 'Logout'),
              onTap: () {
                _authService.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildBody() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 20),
          _buildQRScanButton(),
          const SizedBox(height: 20),
          Expanded(child: _buildTimeCard()),
        ],
      ),
    );
  }

  Widget _buildQRScanButton() {
    return ElevatedButton.icon(
      onPressed: _navigateToQRCodeScanner,
      icon: const Icon(Icons.qr_code_scanner, size: 50),
      label: Text(AppLocalizations.of(context)!.scanQRCode),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildTimeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(AppLocalizations.of(context)!.timecard,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _timeCard.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading:
                      const Icon(Icons.access_time, color: Colors.blueAccent),
                  title: Text('${_timeCard[index]['type']}'),
                  subtitle: Text(DateFormat('HH:mm')
                      .format(_timeCard[index]['timestamp'].toDate())),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

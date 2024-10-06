import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'attendance_service.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'qr_scan_page.dart';
import 'profile_page.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late AttendanceService _attendanceService;
  late AuthService _authService;
  late LocationService _locationService;
  String? _employeeId;
  String? _nip;
  bool _isLocationAllowed = false;
  String? lastActivity;
  List<Map<String, dynamic>> timeCard = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _attendanceService = AttendanceService();
    _authService = Provider.of<AuthService>(context, listen: false);
    _locationService = LocationService();

    await _fetchCurrentUser();
    if (_nip != null) {
      await _checkAndRequestPermissions();
      await _updateLastActivity();
      await _loadTodayAttendance();
    }
  }

  Future<void> _fetchCurrentUser() async {
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
  }

  Future<void> _checkAndRequestPermissions() async {
    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    if (locationPermission == LocationPermission.deniedForever) {
      _showPermissionError(
          'Location permission denied permanently. Please enable it in settings.');
      openAppSettings();
    } else if (locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse) {
      await _checkLocation();
    } else {
      _showPermissionError(
          'Location permission is required to mark attendance.');
    }

    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<void> _checkLocation() async {
    _isLocationAllowed =
        await _locationService.isWithinAllowedLocation(radius: 200.0);
    setState(() {});
  }

  Future<void> _updateLastActivity() async {
    if (_nip != null) {
      lastActivity = await _attendanceService.getLastActivity(_nip!);
      setState(() {});
    }
  }

  Future<void> _loadTodayAttendance() async {
    if (_nip != null) {
      timeCard =
          await _attendanceService.getAttendanceForDate(_nip!, DateTime.now());
      setState(() {});
    }
  }

  Future<void> _markAttendance(String activity, [DateTime? timestamp]) async {
    if (_nip != null && _isLocationAllowed) {
      DateTime now = timestamp ?? DateTime.now();
      await _attendanceService.markAttendance(_nip!, activity);
      _showSuccessNotification(
          'Attendance marked: $activity at ${DateFormat('HH:mm').format(now)}');
      await _updateLastActivity();
      await _loadTodayAttendance();
    } else if (!_isLocationAllowed) {
      _showLocationError();
    }
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are not within the allowed location.'),
      ),
    );
  }

  void _showPermissionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showSuccessNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _navigateToQRCodeScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScanPage(
          onAttendanceMarked: (nip, activity, timestamp) {
            _markAttendance(activity, timestamp);
            timeCard.add({
              'activity': activity,
              'timestamp': timestamp,
            });
            setState(() {});
          },
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SatuBC Absensi'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _authService.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_nip ?? 'Loading...'),
              accountEmail: Text('Employee at DJBC'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.blueAccent),
              ),
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: _navigateToProfile,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                _authService.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blueAccent,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome, $_nip',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _isLocationAllowed
                        ? const Text(
                            'You are within the allowed location.',
                            style: TextStyle(color: Colors.white),
                          )
                        : const Text(
                            'You are not within the allowed location!',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildAttendanceCard('Check-in', Icons.login, Colors.green),
                  _buildAttendanceCard('Break', Icons.coffee, Colors.orange),
                  _buildAttendanceCard('Check-out', Icons.logout, Colors.red),
                  ElevatedButton.icon(
                    onPressed: _navigateToQRCodeScanner,
                    icon: const Icon(Icons.qr_code_scanner, size: 50),
                    label: const Text('QR Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Timecard',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: timeCard.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading:
                              Icon(Icons.access_time, color: Colors.blueAccent),
                          title: Text('${timeCard[index]['activity']}'),
                          subtitle: Text(DateFormat('HH:mm')
                              .format(timeCard[index]['timestamp'].toDate())),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(String activity, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 4,
      child: InkWell(
        onTap: () => _markAttendance(activity),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: color.withOpacity(0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 8),
              Text(
                activity,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

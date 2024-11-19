import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'attendance_service.dart';
import 'auth_service.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late AttendanceService _attendanceService;
  late AuthService _authService;
  String? _employeeId;
  Map<DateTime, List<Map<String, dynamic>>> _groupedAttendanceHistory = {};
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _authService = Provider.of<AuthService>(context, listen: false);
    _attendanceService = AttendanceService(_authService);
    _employeeId = await _attendanceService.getEmployeeId();

    if (_employeeId != null) {
      await _loadAttendanceHistory();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() => _isLoading = true);
    try {
      var history = await _attendanceService.getAttendanceHistory(
          _employeeId!, _startDate, _endDate);

      _groupedAttendanceHistory = {};
      for (var day in history) {
        DateTime date = (day['date'] as Timestamp).toDate();
        date = DateTime(date.year, date.month, date.day);
        _groupedAttendanceHistory[date] =
            (day['activities'] as List).map((activity) {
          return {
            'type': activity['type'],
            'timestamp': activity['timestamp'],
          };
        }).toList();
      }
    } catch (e) {
      print("Error loading attendance history: $e");
      _groupedAttendanceHistory = {};
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendanceHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateRangePicker(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedAttendanceHistory.isEmpty
                    ? const Center(child: Text('Tidak ada riwayat absensi'))
                    : ListView.builder(
                        itemCount: _groupedAttendanceHistory.length,
                        itemBuilder: (context, index) {
                          final date =
                              _groupedAttendanceHistory.keys.elementAt(index);
                          final dailyActivities =
                              _groupedAttendanceHistory[date]!;
                          return _buildDailyAttendanceCard(
                              date, dailyActivities);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyAttendanceCard(
      DateTime date, List<Map<String, dynamic>> activities) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ExpansionTile(
        title: Text(
          DateFormat('EEEE, dd MMMM yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: activities
            .map((activity) => ListTile(
                  leading: Icon(_getActivityIcon(activity['type']),
                      color: Colors.blueAccent),
                  title: Text(activity['type']),
                  subtitle: Text(DateFormat('HH:mm')
                      .format(activity['timestamp'].toDate())),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                  initialDateRange:
                      DateTimeRange(start: _startDate, end: _endDate),
                );
                if (picked != null) {
                  setState(() {
                    _startDate = picked.start;
                    _endDate = picked.end;
                  });
                  await _loadAttendanceHistory();
                }
              },
              child: Text(
                  '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String activity) {
    switch (activity.toLowerCase()) {
      case 'masuk':
        return Icons.login;
      case 'istirahat':
        return Icons.coffee;
      case 'pulang':
        return Icons.logout;
      default:
        return Icons.access_time;
    }
  }
}

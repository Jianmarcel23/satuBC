import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'attendance_service.dart';
import 'package:intl/intl.dart';

class QRScanPage extends StatefulWidget {
  final Function(String, String, DateTime) onAttendanceMarked;

  const QRScanPage({super.key, required this.onAttendanceMarked});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? result;
  bool isScanning = true;
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scan')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Scanned Result: ${result ?? ''}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController qrController) {
    controller = qrController;
    qrController.scannedDataStream.listen((scanData) {
      if (isScanning && scanData.code != null && scanData.code!.isNotEmpty) {
        setState(() {
          result = scanData.code;
        });
        _markAttendance(scanData.code!);
      }
    });
  }

  void _markAttendance(String nip) async {
    if (isScanning) {
      isScanning = false;
      String? lastActivity = await _attendanceService.getLastActivity(nip);
      DateTime now = DateTime.now();

      String activity;

      // Determine next activity
      if (lastActivity == null) {
        activity = 'Check-in ';
      } else if (lastActivity == 'Check-in') {
        activity = 'Break';
      } else if (lastActivity == 'Break') {
        activity = 'Check-out';
      } else {
        _showAlertDialog('Error', 'You have already checked out for today.');
        isScanning = true;
        return;
      }

      try {
        await _attendanceService.markAttendance(nip, activity);
        widget.onAttendanceMarked(nip, activity, now);
        _showAlertDialog('Success',
            'Attendance marked as $activity at ${DateFormat('HH:mm').format(now)}');
      } catch (e) {
        _showAlertDialog('Error', 'Failed to mark attendance: $e');
      } finally {
        isScanning = true;
      }
    }
  }

  void _showAlertDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.pop(context);
                if (title == 'Success') {
                  Navigator.pushReplacementNamed(context, '/main');
                }
              },
            ),
          ],
        );
      },
    );
  }
}

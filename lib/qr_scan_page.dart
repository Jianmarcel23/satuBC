import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:satubc/auth_service.dart';
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
  bool isProcessing = false;
  bool isDialogShowing = false;
  final AttendanceService _attendanceService = AttendanceService(AuthService());
  final AuthService _authService = AuthService();

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

  void _pauseScanner() {
    if (controller != null && isScanning) {
      controller!.pauseCamera();
      setState(() {
        isScanning = false;
      });
    }
  }

  void _resumeScanner() {
    if (controller != null && !isScanning) {
      controller!.resumeCamera();
      setState(() {
        isScanning = true;
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai QR untuk Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              await controller?.toggleFlash();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 4,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.blue,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 300,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Arahkan kamera ke kode QR',
                        style: TextStyle(fontSize: 16),
                      ),
                      if (isProcessing)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController qrController) {
    setState(() {
      controller = qrController;
    });

    qrController.scannedDataStream.listen((scanData) {
      if (isScanning &&
          !isProcessing &&
          !isDialogShowing &&
          scanData.code != null &&
          scanData.code!.isNotEmpty) {
        setState(() {
          isProcessing = true;
        });
        _pauseScanner();
        _processAttendance(scanData.code!);
      }
    });
  }

  void _processAttendance(String scannedData) async {
    try {
      String? currentEmployeeId = await _attendanceService.getEmployeeId();
      if (currentEmployeeId == null) {
        _showErrorDialog('Tidak dapat mengambil ID karyawan.');
        return;
      }

      var currentUser = _authService.currentUser;
      if (currentUser == null || currentUser.displayName != scannedData) {
        _showErrorDialog('Data QR yang dipindai tidak valid.');
        return;
      }

      DateTime now = DateTime.now();
      List<Map<String, dynamic>> todayAttendance =
          await _attendanceService.getAttendanceForDate(currentEmployeeId, now);

      String nextActivity = _determineNextActivity(todayAttendance);

      if (nextActivity.isNotEmpty) {
        _showConfirmationDialog(currentEmployeeId, nextActivity, now);
      } else {
        _showInfoDialog('Anda telah menyelesaikan absensi hari ini.');
      }
    } catch (e) {
      _showErrorDialog('Gagal memproses absensi: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  String _determineNextActivity(List<Map<String, dynamic>> todayAttendance) {
    if (todayAttendance.isEmpty) {
      return 'masuk';
    } else if (todayAttendance.length == 1 &&
        todayAttendance.first['type'] == 'masuk') {
      return 'istirahat';
    } else if (todayAttendance.length == 2 &&
        todayAttendance.last['type'] == 'istirahat') {
      return 'pulang';
    }
    return '';
  }

  void _showConfirmationDialog(
      String employeeId, String activity, DateTime now) {
    setState(() {
      isDialogShowing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Konfirmasi Absensi'),
            content: Text('Apakah Anda ingin melakukan absensi $activity?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Batal'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    isDialogShowing = false;
                  });
                  _resumeScanner();
                },
              ),
              TextButton(
                child: const Text('Ya'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _markAttendance(employeeId, activity, now);
                  setState(() {
                    isDialogShowing = false;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markAttendance(
      String employeeId, String activity, DateTime now) async {
    try {
      setState(() {
        isProcessing = true;
      });

      await _attendanceService.markAttendance(employeeId, activity);
      widget.onAttendanceMarked(employeeId, activity, now);

      _showSuccessDialog(
          'Absensi $activity dicatat pada ${DateFormat('HH:mm').format(now)}');
    } catch (e) {
      _showErrorDialog('Gagal mencatat absensi: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    _showDialog('Sukses', message, true);
  }

  void _showErrorDialog(String message) {
    _showDialog('Kesalahan', message, false);
  }

  void _showInfoDialog(String message) {
    _showDialog('Informasi', message, true);
  }

  void _showDialog(String title, String content, bool navigateOnClose) {
    setState(() {
      isDialogShowing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    isDialogShowing = false;
                  });
                  if (navigateOnClose) {
                    Navigator.of(context).pushReplacementNamed('/main');
                  } else {
                    _resumeScanner();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

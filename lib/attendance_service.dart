import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Layanan untuk mengelola absensi pegawai menggunakan Firestore.
class AttendanceService {
  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AttendanceService(this._authService);

  /// Menandai absensi pegawai.
  ///
  /// [employeeId] adalah ID unik pegawai.
  /// [activity] adalah jenis aktivitas absensi (misalnya: masuk, istirahat, pulang).
  ///
  /// Metode ini akan membuat atau memperbarui dokumen absensi untuk hari ini
  /// di dalam koleksi 'attendance/{employeeId}/daily_records/'.
  Future<void> markAttendance(String employeeId, String activity) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      DocumentReference employeeAttendanceRef = _firestore
          .collection('attendance')
          .doc(employeeId)
          .collection('daily_records')
          .doc(today.toIso8601String());

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot attendanceSnapshot =
            await transaction.get(employeeAttendanceRef);

        if (!attendanceSnapshot.exists) {
          // Jika dokumen untuk hari ini belum ada, buat baru
          transaction.set(employeeAttendanceRef, {
            'date': today,
            'activities': [
              {
                'type': activity,
                'timestamp': now,
              }
            ]
          });
        } else {
          // Jika dokumen sudah ada, tambahkan aktivitas baru
          List<dynamic> activities = (attendanceSnapshot.data()
                  as Map<String, dynamic>)['activities'] ??
              [];
          activities.add({
            'type': activity,
            'timestamp': now,
          });
          transaction.update(employeeAttendanceRef, {'activities': activities});
        }
      });

      print('Absensi tercatat untuk $activity pada ${today.toIso8601String()}');
    } catch (e) {
      print('Error dalam markAttendance: $e');
      rethrow; // Melempar kembali error untuk penanganan di UI
    }
  }

  /// Mendapatkan catatan absensi untuk tanggal tertentu.
  ///
  /// [employeeId] adalah ID unik pegawai.
  /// [date] adalah tanggal yang ingin dilihat catatannya.
  ///
  /// Mengembalikan List dari Map yang berisi data absensi.
  Future<List<Map<String, dynamic>>> getAttendanceForDate(
      String employeeId, DateTime date) async {
    try {
      final targetDate = DateTime(date.year, date.month, date.day);

      DocumentSnapshot attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(employeeId)
          .collection('daily_records')
          .doc(targetDate.toIso8601String())
          .get();

      if (attendanceSnapshot.exists) {
        final data = attendanceSnapshot.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['activities'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error dalam getAttendanceForDate: $e');
      return [];
    }
  }

  /// Mendapatkan riwayat absensi untuk periode tertentu.
  ///
  /// [employeeId] adalah ID unik pegawai.
  /// [startDate] adalah tanggal awal periode yang ingin dilihat.
  /// [endDate] adalah tanggal akhir periode (opsional, default: hari ini).
  ///
  /// Mengembalikan List dari Map yang berisi data riwayat absensi.
  Future<List<Map<String, dynamic>>> getAttendanceHistory(
      String employeeId, DateTime startDate, DateTime endDate) async {
    try {
      QuerySnapshot attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(employeeId)
          .collection('daily_records')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date', descending: true)
          .get();

      return attendanceSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'date': data['date'],
          'activities': data['activities'],
        };
      }).toList();
    } catch (e) {
      print('Error in getAttendanceHistory: $e');
      return [];
    }
  }

  /// Mendapatkan ID pegawai yang sedang login.
  ///
  /// Mengembalikan String ID pegawai atau null jika tidak ditemukan.
  Future<String?> getEmployeeId() async {
    final userData = await _authService.getCurrentUserData();
    return userData?['id']; // Asumsi 'id' adalah field untuk ID pegawai
  }
}

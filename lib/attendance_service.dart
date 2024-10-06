import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to mark attendance
  Future<void> markAttendance(String nip, String activity) async {
    try {
      DateTime now = DateTime.now();
      String formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}"; // YYYY-MM-DD format

      // Get the employee document based on NIP
      QuerySnapshot<Map<String, dynamic>> result = await _firestore
          .collection('employees')
          .where('NIP', isEqualTo: nip)
          .get();

      if (result.docs.isNotEmpty) {
        String employeeId = result.docs.first.id;

        // Store attendance data under 'attendance' subcollection, grouped by date
        await _firestore
            .collection('employees')
            .doc(employeeId)
            .collection('attendance')
            .doc(formattedDate) // Document for the specific date
            .collection(
                'activities') // Subcollection for activities within the date
            .add({
          'activity': activity,
          'timestamp': now,
        });

        print('Attendance marked for $activity');
      } else {
        print('No employee found with this NIP');
      }
    } catch (e) {
      print('Error in markAttendance: ${e.toString()}');
    }
  }

  // Function to get the last attendance activity of an employee
  Future<String?> getLastActivity(String nip) async {
    try {
      QuerySnapshot<Map<String, dynamic>> result = await _firestore
          .collection('employees')
          .where('NIP', isEqualTo: nip)
          .get();

      if (result.docs.isNotEmpty) {
        String employeeId = result.docs.first.id;

        // Fetch the last activity based on the timestamp in descending order
        var attendanceSnapshot = await _firestore
            .collection('employees')
            .doc(employeeId)
            .collection('attendance')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (attendanceSnapshot.docs.isNotEmpty) {
          return attendanceSnapshot.docs.first.data()['activity'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('Error in getLastActivity: ${e.toString()}');
      return null;
    }
  }

  // Function to retrieve all attendance records for a given day
  Future<List<Map<String, dynamic>>> getAttendanceForDate(
      String nip, DateTime date) async {
    try {
      String formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      QuerySnapshot<Map<String, dynamic>> result = await _firestore
          .collection('employees')
          .where('NIP', isEqualTo: nip)
          .get();

      if (result.docs.isNotEmpty) {
        String employeeId = result.docs.first.id;

        var attendanceSnapshot = await _firestore
            .collection('employees')
            .doc(employeeId)
            .collection('attendance')
            .doc(formattedDate)
            .collection('activities')
            .orderBy('timestamp', descending: true)
            .get();

        return attendanceSnapshot.docs
            .map((doc) => doc.data())
            .toList(); // Return list of attendance records
      }
      return [];
    } catch (e) {
      print('Error in getAttendanceForDate: ${e.toString()}');
      return [];
    }
  }
}

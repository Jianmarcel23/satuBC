import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getter untuk current user
  User? get currentUser => _auth.currentUser;

  // Mendapatkan ID karyawan berdasarkan NIP
  Future<String?> getEmployeeIdByNip(String nip) async {
    try {
      QuerySnapshot<Map<String, dynamic>> result = await _firestore
          .collection('employees')
          .where('NIP', isEqualTo: nip)
          .get();

      if (result.docs.isNotEmpty) {
        return result.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error in getEmployeeIdByNip: ${e.toString()}');
      return null;
    }
  }

  // Metode baru untuk mendapatkan data user saat ini
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        String? nip =
            currentUser.displayName; // Assuming NIP is stored in displayName
        if (nip != null) {
          QuerySnapshot<Map<String, dynamic>> result = await _firestore
              .collection('employees')
              .where('NIP', isEqualTo: nip)
              .get();

          if (result.docs.isNotEmpty) {
            return {
              'id': result.docs.first.id,
              'nip': nip,
              ...result.docs.first.data()
            };
          }
        }
      }
      return null;
    } catch (e) {
      print('Error in getCurrentUserData: ${e.toString()}');
      return null;
    }
  }

  Future<User?> signInWithNip(String nip, String password) async {
    try {
      QuerySnapshot<Map<String, dynamic>> result = await _firestore
          .collection('employees')
          .where('NIP', isEqualTo: nip)
          .get();

      if (result.docs.isNotEmpty) {
        var userData = result.docs.first.data();

        if (userData['password'] == password) {
          UserCredential userCredential = await _auth.signInAnonymously();

          // Store additional user info in Firebase Auth
          await userCredential.user
              ?.updateDisplayName(nip); // Store NIP in displayName

          notifyListeners();
          return userCredential.user;
        } else {
          print('Invalid password');
          return null;
        }
      } else {
        print('No user found with this NIP');
        return null;
      }
    } catch (e) {
      print('Error in signInWithNip: ${e.toString()}');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}

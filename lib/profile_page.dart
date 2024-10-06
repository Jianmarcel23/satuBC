import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  final String employeeId;

  const ProfilePage({super.key, required this.employeeId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userProfile;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      if (snapshot.exists) {
        setState(() {
          userProfile = snapshot.data() as Map<String, dynamic>;
          errorMessage = null;
        });
      } else {
        setState(() {
          userProfile = null;
          errorMessage = 'User profile not found';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading profile: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
      ),
      body: errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : userProfile == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Bagian Avatar dan Nama Pegawai
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: AssetImage(
                              'assets/profile_pic.png'), // Replace with actual image
                        ),
                        const SizedBox(height: 20),
                        Text(
                          userProfile!['Nama'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userProfile!['jabatan'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Kartu Informasi Pegawai
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildProfileRow(
                                  'NIP',
                                  userProfile!['NIP'] ?? 'N/A',
                                  Icons.perm_identity,
                                ),
                                const Divider(),
                                _buildProfileRow(
                                  'Email',
                                  userProfile!['email'] ?? 'N/A',
                                  Icons.email,
                                ),
                                const Divider(),
                                _buildProfileRow(
                                  'Jabatan',
                                  userProfile!['jabatan'] ?? 'N/A',
                                  Icons.work,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Tombol untuk melakukan tindakan lain
                        ElevatedButton.icon(
                          onPressed: () {
                            // Implementasikan fungsi edit profil atau fitur lain
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // Fungsi untuk membangun baris informasi profil
  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

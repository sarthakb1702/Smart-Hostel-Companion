// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: unused_import
import '../issues/issue_list_screen.dart';
import '../auth/complete_profile_screen.dart'; 
import '../admin/warden_dashboard.dart'; 
import '../student/student_dashboard.dart';
import '../../services/notification_service.dart';

class RoleHandler extends StatelessWidget {
  const RoleHandler({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 1. Initial Auth Check
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Session expired. Please log in.")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        // 2. Handle Loading and Errors
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("User profile not found in database.")));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;

        // 🛡️ 3. ACCOUNT STATUS CHECK
        bool isActive = userData['isActive'] ?? true;
        if (!isActive) {
          return _buildDeactivatedUI();
        }

        // 🛡️ 4. EXTRACT USER DETAILS
        String role = userData['role'] ?? 'student';
        String hostelType = userData.containsKey('hostelType') ? userData['hostelType'] : 'girls';
        String name = userData['name'] ?? 'User';

        // 🛡️ 5. STUDENT ROUTING (With Profile Completion Check)
        if (role == 'student') {
          bool isProfileComplete = userData['isProfileComplete'] ?? false;
          if (!isProfileComplete) {
            return const CompleteProfileScreen();
          }
          
          // 🔔 Subscribe to notifications
          NotificationService.subscribeToHostel(hostelType, role: role);
          
          // Student Home (Dashboard with Quick Actions)
          return const StudentDashboard();
        } 

        // 🚀 6. STAFF ROUTING (Warden / Head Admin)
        // 🔔 Subscribe staff to role-specific topics
        NotificationService.subscribeToHostel(hostelType, role: role);

        // staff go to the Grid Dashboard with Stats and SOS Logs
        return WardenDashboard(
          role: role,
          hostelType: hostelType,
        );
      },
    );
  }

  // Helper Widget for Deactivated Accounts
  Widget _buildDeactivatedUI() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        color: Colors.grey.shade50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_flipped, color: Colors.red, size: 100),
            const SizedBox(height: 24),
            const Text(
              "ACCESS RESTRICTED",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            const Text(
              "Your account has been deactivated by the administration. Please contact your Warden.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            )
          ],
        ),
      ),
    );
  }
}
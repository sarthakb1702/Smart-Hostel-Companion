import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../issues/issue_list_screen.dart';

class RoleHandler extends StatelessWidget {
  const RoleHandler({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not Logged In")));
    }

    // Using StreamBuilder instead of FutureBuilder so access changes are INSTANT
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("Profile Not Found")));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;

        // 🛡️ 1. CHECK IF ACCOUNT IS ACTIVE
        bool isActive = userData['isActive'] ?? true;

        if (!isActive) {
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
                    "Your account has been deactivated by the administration.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Please visit the Warden's office to resolve this issue.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 40),
                  // Allow them to logout even if blocked
                  ElevatedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  )
                ],
              ),
            ),
          );
        }

        // 🚀 2. IF ACTIVE, PROCEED TO APP
        return IssueListScreen(
          role: userData['role'] ?? 'student',
          hostelType: userData['hostelType'] ?? 'boys',
          name: userData['name'] ?? 'User',
        );
      },
    );
  }
}
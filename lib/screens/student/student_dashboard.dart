import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/housekeeping_section.dart'; // Ensure you created this widget in the previous step

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Student Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User data not found."));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              // 1. Welcome Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hello, ${userData['name'] ?? 'Student'}! 👋",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("Room: ${userData['roomNo'] ?? 'Not Assigned'}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ),
              ),

              // 2. ⭐ HOUSEKEEPING SECTION (Our New Feature)
              const HousekeepingSection(),

              // 3. Quick Stats/Actions Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _buildMenuCard(context, "Parcels", Icons.inventory_2, Colors.orange),
                  _buildMenuCard(context, "Issues", Icons.report_problem, Colors.red),
                  _buildMenuCard(context, "Leave", Icons.exit_to_app, Colors.blue),
                  _buildMenuCard(context, "SOS", Icons.emergency, Colors.purple),
                ],
              ),

              // 4. Recent Notices
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("Recent Notices", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              // You can add a StreamBuilder here later for Hostel Alerts
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Add navigation logic here later
          print("Tapped $title");
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
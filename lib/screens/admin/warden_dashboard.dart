import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_management_screen.dart';
import 'leave_management_screen.dart';
import '../issues/issue_list_screen.dart';
import 'send_invite_screen.dart';
import 'sos_history_screen.dart';
import 'warden_alerts_management_screen.dart';
import 'warden_alerts_management_screen.dart';
import 'warden_parcel_entry_screen.dart';
import 'warden_housekeeping_screen.dart';
class WardenDashboard extends StatelessWidget {
  final String? role;
  final String? hostelType;
  const WardenDashboard({super.key, this.role, this.hostelType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("${(hostelType ?? 'Unknown').toUpperCase()} WARDEN PANEL"),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 Welcome Section
            Text(
              "Welcome, ${(role ?? 'Warden').toUpperCase()}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const Text("Hostel Management Overview", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // 📊 Quick Stats Row
            _buildQuickStats(),

            const SizedBox(height: 25),
            const Text("Departments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // 🚀 Navigation Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _navCard(context, "Maintenance", Icons.build_circle, Colors.orange, 
                    IssueListScreen(role: role, hostelType: hostelType, name: "Warden")),
                  
                  _navCard(context, "Leave Requests", Icons.assignment_turned_in, Colors.green, 
                    LeaveManagementScreen(hostelType: hostelType ?? 'boys')),
                  
                  _navCard(context, "Student List", Icons.groups_rounded, Colors.indigo, 
                    UserManagementScreen(role: role ?? 'warden', hostelType: hostelType ?? 'boys')),
                  
                  _navCard(context, "Add Student", Icons.person_add_alt_1, Colors.blue, 
                    SendInviteScreen(role: role ?? 'warden', hostelType: hostelType ?? 'boys')),

                  // 🚨 SOS HISTORY CARD
                  _navCard(context, "SOS Logs", Icons.history_toggle_off, Colors.red, 
                    SosHistoryScreen(hostelType: hostelType ?? 'boys')),

                  // 📢 BROADCAST ALERTS CARD
                  _navCard(context, "Hostel Alerts", Icons.campaign_rounded, Colors.purple, 
                    WardenAlertsManagementScreen(hostelType: hostelType ?? 'boys')),

                  // 📦 PARCEL MANAGEMENT CARD
                  // 📦 PARCEL MANAGEMENT CARD
                  _navCard(context, "Parcels", Icons.inventory_2_rounded, Colors.brown, 
                    WardenParcelEntryScreen(hostelType: hostelType ?? 'boys')),
                    
                  // ✨ HOUSEKEEPING ANALYTICS CARD
                  _navCard(context, "Housekeeping", Icons.cleaning_services_rounded, Colors.teal, 
                    WardenHousekeepingScreen(hostelType: hostelType ?? 'boys')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STATS BAR ---
  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('issues')
          .where('hostelType', isEqualTo: hostelType ?? 'boys')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              const Icon(Icons.pending_actions, color: Colors.orange),
              const SizedBox(width: 15),
              Text(
                "$pendingCount Pending Maintenance Issues",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- NAV CARD COMPONENT ---
  Widget _navCard(BuildContext context, String title, IconData icon, Color color, Widget destination) {
    return InkWell(
      // ✅ FIXED: Now uses the 'destination' variable passed in the GridView
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
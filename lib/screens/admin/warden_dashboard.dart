// ignore_for_file: duplicate_import

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import '../../services/notification_service.dart'; // 👈 Ensure this path is correct
import 'user_management_screen.dart';
import 'leave_management_screen.dart';
import '../issues/issue_list_screen.dart';
import 'send_invite_screen.dart';
import 'sos_history_screen.dart';
import 'warden_alerts_management_screen.dart';
import 'warden_parcel_entry_screen.dart';
import 'warden_housekeeping_screen.dart';
import 'gate_pass_history_screen.dart';
import 'guest_requests_screen.dart';

class WardenDashboard extends StatefulWidget {
  final String? role;
  final String? hostelType;
  const WardenDashboard({super.key, this.role, this.hostelType});

  @override
  State<WardenDashboard> createState() => _WardenDashboardState();
}

class _WardenDashboardState extends State<WardenDashboard> {
  
  @override
  void initState() {
    super.initState();
    // 🔔 INITIALIZE BUILDING-SPECIFIC SECURITY
    _initializeSecurityProtocols();
  }

  // 🛡️ SECURITY & NOTIFICATION SYNC
  void _initializeSecurityProtocols() async {
    if (widget.hostelType != null) {
      // Automatically subscribe this device to the correct building's SOS and Gate Pass alerts
      await NotificationService.subscribeToHostel(
        widget.hostelType!, 
        role: widget.role ?? 'warden'
      );
      
      // Clear alerts from the "other" building to prevent noise
      String otherTopic = widget.hostelType!.toLowerCase() == 'boys' ? 'warden_girls' : 'warden_boys';
      await FirebaseMessaging.instance.unsubscribeFromTopic(otherTopic);
      
      debugPrint("Warden Dashboard Initialized for: ${widget.hostelType}");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 ROLE-BASED ACCESS CONTROL (RBAC)
    // Only Head Admin or Girls' Warden can see the movement logs
    final bool showGatePass = widget.role == 'head_admin' || (widget.hostelType?.toLowerCase() == 'girls');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.role == 'head_admin' ? "HEAD ADMIN PANEL" : "${(widget.hostelType ?? 'Unknown').toUpperCase()} WARDEN PANEL"),
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Logout",
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
              "Welcome, ${(widget.role ?? 'Warden').toUpperCase()}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const Text("Real-time Hostel Monitoring", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // 📊 Dynamic Stats (Filtered by building)
            _buildQuickStats(),

            const SizedBox(height: 25),
            const Text("Control Center", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // 🚀 Navigation Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _navCard(context, "Maintenance", Icons.build_circle, Colors.orange, 
                    IssueListScreen(role: widget.role, hostelType: widget.hostelType, name: "Warden")),
                  
                  _navCard(context, "Leave Requests", Icons.assignment_turned_in, Colors.green, 
                    LeaveManagementScreen(hostelType: widget.hostelType ?? 'boys', role: widget.role)),
                  
                  _navCard(context, "Student List", Icons.groups_rounded, Colors.indigo, 
                    UserManagementScreen(role: widget.role ?? 'warden', hostelType: widget.hostelType ?? 'boys')),
                  
                  _navCard(context, "Add Student", Icons.person_add_alt_1, Colors.blue, 
                    SendInviteScreen(role: widget.role ?? 'warden', hostelType: widget.hostelType ?? 'boys')),

                  _navCard(context, "SOS Logs", Icons.history_toggle_off, Colors.red, 
                    SosHistoryScreen(hostelType: widget.hostelType ?? 'boys', role: widget.role)),
                 _navCard(
  context,
  "Guest Requests",
  Icons.person,
  Colors.orange,
  const GuestRequestsScreen(),
),
                  _navCard(context, "Hostel Alerts", Icons.campaign_rounded, Colors.purple, 
                    WardenAlertsManagementScreen(hostelType: widget.hostelType ?? 'boys', role: widget.role)),

                  _navCard(context, "Parcels", Icons.inventory_2_rounded, Colors.brown, 
                    WardenParcelEntryScreen(hostelType: widget.hostelType ?? 'boys', role: widget.role)),
                    
                  _navCard(context, "Housekeeping", Icons.cleaning_services_rounded, Colors.teal, 
                    WardenHousekeepingScreen(hostelType: widget.hostelType ?? 'boys', role: widget.role)),

                  // ✨ THE GATE PASS CARD (Conditional Visibility)
                  if (showGatePass) 
                    _navCard(context, "Gate Passes", Icons.sensor_door_outlined, Colors.pink, 
                      GatePassHistoryScreen(
                        hostelType: widget.hostelType ?? 'girls', 
                        role: widget.role ?? 'warden'
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI: STATS BAR (Real-time count for specific building) ---
  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('issues')
          .where('hostelType', isEqualTo: widget.hostelType ?? 'boys')
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
              Expanded(
                child: Text(
                  "$pendingCount Unresolved Maintenance Tasks",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- UI: NAV CARD COMPONENT ---
  Widget _navCard(BuildContext context, String title, IconData icon, Color color, Widget destination) {
    return InkWell(
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
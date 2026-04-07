import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colours.dart';
import '../../services/sos_service.dart';
import '../../services/parcel_service.dart';
import '../../services/alert_service.dart';
import '../issues/issue_list_screen.dart'; 
import '../issues/my_leaves_screen.dart';
import '../issues/student_parcel_list_screen.dart';
import '../admin/sos_history_screen.dart';
import 'housekeeping_screen.dart'; 
import '../profile/student_profile_tab.dart';
import 'student_alerts_tab.dart';
import '../../widgets/housekeeping_section.dart';
import 'gate_pass_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  final user = FirebaseAuth.instance.currentUser;

  void _onItemTapped(int index) async {
    if (index == 3) {
      bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout"),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showSosModal(BuildContext context, String name, String hostelType) {
    String description = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emergency_share, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            const Text("Emergency SOS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            const Text("This will alert the Warden and Head Admin immediately.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              onChanged: (val) => description = val,
              decoration: const InputDecoration(
                labelText: "Describe your emergency (e.g., Room 517, Medical)...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  // 📍 CHECK GPS PERMISSIONS
                  await Geolocator.requestPermission();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending SOS Alert..."), backgroundColor: Colors.red));
                  }
                  try {
                    await SosService.triggerSos(
                      name: name,
                      hostel: hostelType,
                      description: description.isEmpty ? "Direct Emergency Alert" : description,
                      recipientName: "Warden",
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emergency Alert Sent to Warden!"), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Network Error: SOS not sent. Please check your internet."), 
                          backgroundColor: Colors.orange,
                        )
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("CONFIRM SOS", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String name = userData['name'] ?? 'User';
        String roomNo = userData.containsKey('roomNo') ? userData['roomNo'] : 'N/A';
        String hostelType = userData.containsKey('hostelType') ? userData['hostelType'] : 'girls';

        final List<Widget> screens = [
          _homeContent(context, name, roomNo, hostelType), // 0
          const StudentProfileTab(), // 1
          StudentAlertsTab(hostelType: hostelType),  // 2
          const SizedBox(), // 3 (logout)
        ];

        return Scaffold(
          body: Container(
            color: AppColors.background,
            child: SafeArea(
              child: screens[_selectedIndex],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Alerts"),
              BottomNavigationBarItem(icon: Icon(Icons.logout), label: "Logout"),
            ],
          ),
        );
      },
    );
  }

  Widget _homeContent(BuildContext context, String name, String roomNo, String hostelType) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Welcome, \n${name.split(' ').first}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() { _selectedIndex = 2; });
                },
                child: const Icon(Icons.notifications_none, size: 30, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 🔹 SLIM PROFILE CARD (Matches Warden's Pending Issues shape)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.lightGrey,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("${hostelType.toUpperCase()} • Room $roomNo", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ✨ HOUSEKEEPING SECTION
          HousekeepingSection(hostelType: hostelType),

          const SizedBox(height: 25),
          const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // 🚀 NAVIGATION GRID (Matching Warden Dashboard)
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _navCard(
                  context, 
                  "Issues", 
                  Icons.build_circle, 
                  Colors.orange, 
                  destination: IssueListScreen(role: 'student', hostelType: hostelType, name: name),
                ),
                
                _navCard(
                  context, 
                  "Housekeeping", 
                  Icons.cleaning_services_rounded, 
                  Colors.teal, 
                  destination: HousekeepingScreen(hostelType: hostelType),
                ),
                
                _navCard(
                  context, 
                  "Leave Requests", 
                  Icons.assignment_turned_in, 
                  Colors.green, 
                  destination: const MyLeavesScreen(),
                ),
                
                // 📦 PARCELS STREAM CARD
                StreamBuilder<QuerySnapshot>(
                  stream: ParcelService().getStudentParcelsStream(user!.uid, hostelType),
                  builder: (context, snapshot) {
                    int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _navCard(
                      context, 
                      "Parcels", 
                      Icons.inventory_2_rounded, 
                      Colors.brown, 
                      destination: StudentParcelListScreen(hostelType: hostelType, recipientName: name),
                    );
                  },
                ),

                // 🚨 EMERGENCY SOS TRIGGER
                _navCard(
                  context, 
                  "Emergency SOS", 
                  Icons.emergency, 
                  Colors.red, 
                  onTap: () => _showSosModal(context, name, hostelType),
                ),

                _navCard(
                  context, 
                  "SOS Logs", 
                  Icons.history_toggle_off, 
                  Colors.purple, 
                  destination: SosHistoryScreen(hostelType: hostelType, role: 'student'),
                ),

                // 🚪 GATE PASS (Girls Only)
                if (hostelType == 'girls')
                  _navCard(
                    context, 
                    "Gate Pass", 
                    Icons.sensor_door_outlined, 
                    Colors.pink, 
                    destination: GatePassScreen(
                      hostelType: hostelType, 
                      userName: name,
                      roomNo: roomNo,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WARDEN-STYLE NAV CARD COMPONENT ---
  Widget _navCard(BuildContext context, String title, IconData icon, Color color, 
      {Widget? destination, VoidCallback? onTap, int? badgeCount}) {
    return InkWell(
      onTap: onTap ?? () {
        if (destination != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        }
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
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
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
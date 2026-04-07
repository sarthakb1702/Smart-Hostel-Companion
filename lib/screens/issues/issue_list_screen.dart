import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'create_issue_screen.dart';
import 'my_leaves_screen.dart'; 
import '../profile/student_profile_tab.dart'; 
import 'hostel_alerts_screen.dart';
import 'student_parcel_list_screen.dart';
import '../../services/sos_service.dart';
import '../../services/housekeeping_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class IssueListScreen extends StatefulWidget {
  final String? role;
  final String? hostelType;
  final String? name;
  const IssueListScreen({
    super.key,
    this.role,
    this.hostelType,
    this.name,
  });

  @override
  State<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends State<IssueListScreen> {
  int _currentIndex = 0; 
  String _selectedStatus = 'all';
  String _currentHostelView = '';

  @override
  void initState() {
    super.initState();
    _currentHostelView = widget.hostelType ?? '';
    
    // 🚨 Listen for Notification clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'hostel_alert') {
        setState(() => _currentIndex = 3); // Jump to Alerts
      } else if (message.data['type'] == 'parcel_received') {
        setState(() => _currentIndex = 4); // Jump to Parcels
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnapshot) {
        String assignedRoom = "Loading...";
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          assignedRoom = userSnapshot.data!.get('roomNo') ?? "Not Assigned";
        }

        if ((widget.role ?? 'student') != 'student') {
          return Scaffold(
            appBar: AppBar(title: const Text("MAINTENANCE ISSUES")),
            body: _buildIssueListBody(),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_getTitle()),
            actions: [
              IconButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.indigo,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.build_outlined), label: "Issues"),
              BottomNavigationBarItem(icon: Icon(Icons.exit_to_app_outlined), label: "Leaves"),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
              BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: "Alerts"),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: "Parcels"), // 📦 Tab 4
            ],
          ),
          floatingActionButton: (_currentIndex == 0) 
              ? _buildStudentFAB(assignedRoom) 
              : null,
          body: _buildStudentTabBody(),
        );
      },
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0: return "MAINTENANCE";
      case 1: return "LEAVE REQUESTS";
      case 2: return "MY PROFILE";
      case 3: return "HOSTEL ALERTS";
      case 4: return "MY PARCELS"; // 📦
      default: return "";
    }
  }

  Widget _buildStudentTabBody() {
    switch (_currentIndex) {
      case 0: return _buildIssueListBody();
      case 1: return const MyLeavesScreen(); 
      case 2: return const StudentProfileTab();
      case 3: return HostelAlertsScreen(hostelType: widget.hostelType ?? 'boys');
      case 4: return StudentParcelListScreen(hostelType: widget.hostelType ?? 'boys', recipientName: widget.name ?? 'Unknown Resident'); // 📦
      default: return const SizedBox();
    }
  }

  // --- Logic & Sub-widgets ---

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('issues').doc(docId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _handleSosTrigger() async {
    String? optionalInfo;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emergency Details"),
        content: TextField(
          decoration: const InputDecoration(hintText: "e.g., Medical help, Fire"),
          onChanged: (val) => optionalInfo = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending SOS Alert..."), backgroundColor: Colors.red));
              try {
                await SosService.triggerSos(
                  name: widget.name ?? "Unknown Resident", 
                  hostel: widget.hostelType ?? "Unknown", 
                  description: (optionalInfo == null || optionalInfo!.isEmpty) ? "SOS from Maintenance Panel" : optionalInfo,
                  recipientName: "Warden", 
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emergency Alert Sent to Warden!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send SOS: $e"), backgroundColor: Colors.orange));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("SEND SOS NOW"),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueListBody() {
    Query query = FirebaseFirestore.instance.collection('issues');
    if ((widget.role ?? 'student') == 'student') {
      query = query.where('createdByUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid);
    } else {
      query = query.where('hostelType', isEqualTo: _currentHostelView);
    }
    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    query = query.orderBy('createdAt', descending: true);

    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No issues found."));
              
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var issue = doc.data() as Map<String, dynamic>;
                  return _buildIssueCard(doc.id, issue);
                },
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          if ((widget.role ?? 'student') == 'head_admin')
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'boys', label: Text('Boys Hostel')),
                  ButtonSegment(value: 'girls', label: Text('Girls Hostel')),
                ],
                selected: {_currentHostelView},
                onSelectionChanged: (val) => setState(() => _currentHostelView = val.first),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'pending', 'in_progress', 'resolved'].map((status) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(status.toUpperCase()),
                    selected: _selectedStatus == status,
                    onSelected: (_) => setState(() => _selectedStatus = status),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(String docId, Map<String, dynamic> issue) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(issue['title'] ?? 'No Title'),
        subtitle: Text("${issue['description']}\nRoom: ${issue.containsKey('roomNo') ? issue['roomNo'] : 'N/A'}"),
        trailing: (widget.role ?? 'student') != 'student' 
          ? PopupMenuButton<String>(
              onSelected: (val) => _updateStatus(docId, val),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pending', child: Text("Pending")),
                const PopupMenuItem(value: 'in_progress', child: Text("In Progress")),
                const PopupMenuItem(value: 'resolved', child: Text("Resolved")),
              ],
              child: _StatusChip(status: issue['status']),
            )
          : _StatusChip(status: issue['status']),
      ),
    );
  }

  Widget _buildStudentFAB(String assignedRoom) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: "sos",
          onPressed: _handleSosTrigger,
          backgroundColor: Colors.red,
          icon: const Icon(Icons.warning, color: Colors.white),
          label: const Text("SOS", style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: "issue",
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => CreateIssueScreen(
              studentName: widget.name ?? 'Unknown', 
              hostelType: widget.hostelType ?? 'Unknown', 
              roomNo: assignedRoom))),
          label: const Text("Report Issue"),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip({this.status});
  @override
  Widget build(BuildContext context) {
    Color c = status == 'resolved' ? Colors.green : (status == 'in_progress' ? Colors.blue : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withOpacity(0.5))),
      child: Text(status?.toUpperCase() ?? 'PENDING', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
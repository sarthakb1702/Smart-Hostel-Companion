import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🚨 Added
import 'create_issue_screen.dart';
import 'my_leaves_screen.dart'; 
import '../profile/student_profile_tab.dart'; 
import 'hostel_alerts_screen.dart'; // 🚨 Import your new alerts screen
import '../../services/sos_service.dart';

class IssueListScreen extends StatefulWidget {
  final String role, hostelType, name;
  const IssueListScreen({
    super.key,
    required this.role,
    required this.hostelType,
    required this.name,
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
    _currentHostelView = widget.hostelType;
    
    // 🚨 Listen for Notification clicks while the app is in foreground/background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'hostel_alert') {
        setState(() => _currentIndex = 3); // Jump to Alerts Tab
      }
    });
  }

  // --- UI BUILDERS ---

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

        // Warden View (Management remains as before)
        if (widget.role != 'student') {
          return Scaffold(
            appBar: AppBar(title: const Text("MAINTENANCE ISSUES")),
            body: _buildIssueListBody(),
          );
        }

        // Student view with 4 Tabs (Added Alerts)
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
              BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: "Alerts"), // 🚨 Tab 3
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
      default: return "";
    }
  }

  Widget _buildStudentTabBody() {
    switch (_currentIndex) {
      case 0: return _buildIssueListBody();
      case 1: return const MyLeavesScreen(); 
      case 2: return const StudentProfileTab();
      case 3: return HostelAlertsScreen(hostelType: widget.hostelType); // 🚨 New Screen
      default: return const SizedBox();
    }
  }

  // ... (Keep your _updateStatus, _handleSosTrigger, _buildIssueListBody, _buildFilters, _buildIssueCard, and _buildStudentFAB exactly as they were) ...
  
  // Existing methods from your code continue below...
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
            onPressed: () {
              Navigator.pop(context);
              SosService.triggerSos(name: widget.name, hostel: widget.hostelType, description: optionalInfo);
            },
            child: const Text("SEND SOS"),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueListBody() {
    Query query = FirebaseFirestore.instance.collection('issues');
    if (widget.role == 'student') {
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
          if (widget.role == 'head_admin')
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
        subtitle: Text("${issue['description']}\nRoom: ${issue['roomNo']}"),
        trailing: widget.role != 'student' 
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
              studentName: widget.name, 
              hostelType: widget.hostelType, 
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
    // Define colors based on the status string
    Color c;
    switch (status?.toLowerCase()) {
      case 'resolved':
        c = Colors.green;
        break;
      case 'in_progress':
        c = Colors.blue;
        break;
      case 'pending':
      default:
        c = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(
        status?.toUpperCase() ?? 'PENDING',
        style: TextStyle(
          color: c,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
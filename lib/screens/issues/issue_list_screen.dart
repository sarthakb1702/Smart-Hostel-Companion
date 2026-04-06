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
            onPressed: () {
              Navigator.pop(context);
              SosService.triggerSos(
                name: widget.name ?? "Unknown Resident", 
                hostel: widget.hostelType ?? "Unknown", 
                description: optionalInfo,
                recipientName: "Warden", // ✅ Added required parameter
              );
            },
            child: const Text("SEND SOS"),
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
        if ((widget.role ?? 'student') == 'student') _buildHousekeepingStatusCard(),
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

  Widget _buildHousekeepingStatusCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: HousekeepingService().getLatestEventStream(widget.hostelType ?? 'boys'),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        bool isActive = data['status'] == 'active';
        Map<String, dynamic> ratings = data['ratings'] ?? {};
        bool hasRated = ratings.containsKey(uid);
        
        if (isActive && !hasRated) {
          // STATE A: Action Required
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.cyan.shade50, Colors.teal.shade50]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.shade300, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cleaning_services_rounded, color: Colors.teal, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text("Housekeeping & Hygiene", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                        builder: (context, val, child) => Transform.scale(
                          scale: val,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                            child: const Text("NEW LOG", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(data['description'] ?? "Full Corridor & Washroom Wash", style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRatingBottomSheet(doc.id, uid),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      icon: const Icon(Icons.star_rate_rounded, color: Colors.white),
                      label: const Text("Rate Today's Cleaning", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // STATE B: Completed/Idle
          String dateString = data['cleaningDate'] != null 
              ? (data['cleaningDate'] as Timestamp).toDate().toString().substring(0, 10)
              : "Unknown Date";
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_outline, color: Colors.green),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Everything looks clean! ✨", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        const SizedBox(height: 4),
                        Text("Last Cleaning Date: $dateString", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {}, 
                    child: const Text("History", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          );
        }
      },
    );
  }

  void _showRatingBottomSheet(String eventId, String uid) {
    double roomRating = 0;
    double bathRating = 0;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Rate Hostel Hygiene", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              const Text("Room Hygiene", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: 0, minRating: 1, direction: Axis.horizontal, itemCount: 5,
                itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: Colors.amber),
                onRatingUpdate: (rating) => roomRating = rating,
              ),
              const SizedBox(height: 20),
              
              const Text("Washroom/Area Hygiene", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: 0, minRating: 1, direction: Axis.horizontal, itemCount: 5,
                itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: Colors.amber),
                onRatingUpdate: (rating) => bathRating = rating,
              ),
              
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (roomRating == 0 || bathRating == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide both ratings")));
                      return;
                    }
                    setSheetState(() => isSubmitting = true);
                    try {
                      await HousekeepingService().submitFeedback(
                        eventId: eventId,
                        uid: uid, 
                        roomRating: roomRating.toInt(), 
                        bathroomRating: bathRating.toInt()
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    } finally {
                      if (context.mounted) setSheetState(() => isSubmitting = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: isSubmitting 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("SUBMIT RATINGS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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
        subtitle: Text("${issue['description']}\nRoom: ${issue['roomNo']}"),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_issue_screen.dart';
import '../admin/send_invite_screen.dart';
import '../admin/user_management_screen.dart';
import '../../services/sos_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_services.dart';

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
  String _selectedStatus = 'all';
  String _currentHostelView = '';

  @override
  void initState() {
    super.initState();

    _currentHostelView = widget.hostelType;
    // Only Wardens and Admins need to register their phone's "Address" (Token)
    if (widget.role == 'warden' || widget.role == 'head_admin') {
      _setupNotifications();
    }
  }

  Future<void> _openMap(String? urlString) async {
  if (urlString == null || urlString.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No location data available")),
    );
    return;
  }

  // 1. Clean the URL (sometimes invisible spaces cause failure)
  final String cleanUrl = urlString.trim();
  final Uri uri = Uri.parse(cleanUrl);

  try {
    // 2. Try launching directly without 'canLaunchUrl' 
    // This is often more successful on modern Android
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    debugPrint("Primary launch failed: $e");
    
    // 3. Fallback: Force it to open in a browser if the Map App fails
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (fallbackError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Could not open map link")),
        );
      }
    }
  }
}

  Future<void> _setupNotifications() async {
    try {
      // We create an instance of the class by adding ()
      // This tells Flutter: "Use the AuthService toolset"
      await AuthService().updateWardenToken();
      print("Warden Notification System Initialized");
    } catch (e) {
      print("Error setting up notifications: $e");
    }
  }

  // --- SOS LOGIC FOR STUDENTS ---
  void _handleSosTrigger() async {
    String? optionalInfo;

    // 1. Show a quick dialog for optional info
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emergency Details (Optional)"),
        content: TextField(
          decoration: const InputDecoration(
            hintText: "e.g., Medical help, Fire, etc.",
          ),
          onChanged: (val) => optionalInfo = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "SKIP & SEND SOS",
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("SEND WITH INFO"),
          ),
        ],
      ),
    );

    // 2. Now send the SOS
    // (Add your existing loading spinner logic here)
    await SosService.triggerSos(
      name: widget.name,
      hostel: widget.hostelType,
      description:
          optionalInfo, // 'optionalInfo' comes from your AlertDialog logic
    );
  }

  // --- UI FOR SOS ALERT POPUP (FOR WARDENS/ADMINS) ---
  // This popup forces the Warden to see the emergency
  void _showEmergencyOverlay(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Text(
          "EMERGENCY ALERT",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Student: ${data['studentName']}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "📍 Room: ${data['roomNo']}",
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "📝 Info: ${data['description']}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),

            // NEW DIRECTIONS BUTTON
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 45),
              ),
              icon: const Icon(Icons.map),
              label: const Text("GET GPS DIRECTIONS"),
              onPressed: () => _launchMap(data['location']['googleMapsUrl']),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('sos_alerts')
                  .doc(docId)
                  .update({'status': 'resolved'});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              "MARK AS SAFE",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('issues').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
Widget build(BuildContext context) {
  // 1. First, define the query for the list
  Query query = FirebaseFirestore.instance.collection('issues');

  if (widget.role == 'student') {
    query = query.where(
      'createdByUid',
      isEqualTo: FirebaseAuth.instance.currentUser?.uid,
    );
  } else {
    query = query.where('hostelType', isEqualTo: _currentHostelView);
  }

  if (_selectedStatus != 'all') {
    query = query.where('status', isEqualTo: _selectedStatus);
  }

  query = query.orderBy('createdAt', descending: true);

  // 2. Wrap the UI in a FutureBuilder to fetch the student's Room Number
  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get(),
    builder: (context, userSnapshot) {
      // Logic to get the room number or show a placeholder
      String assignedRoom = "Loading...";
      if (userSnapshot.hasData && userSnapshot.data!.exists) {
        assignedRoom = userSnapshot.data!.get('roomNo') ?? "Not Assigned";
      }

      return Scaffold(
        appBar: AppBar(
          title: Text("${widget.role.toUpperCase()} VIEW"),
          actions: [
            if (widget.role != 'student') ...[
              IconButton(
                icon: const Icon(Icons.manage_accounts),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserManagementScreen(
                      role: widget.role,
                      hostelType: widget.hostelType,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SendInviteScreen(
                      role: widget.role,
                      hostelType: widget.hostelType,
                    ),
                  ),
                ),
              ),
            ],
            IconButton(
              onPressed: () async {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 📡 REAL-TIME SOS LISTENER (Warden/Admin only)
            if (widget.role != 'student')
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sos_alerts')
                    .where('hostelType', isEqualTo: _currentHostelView)
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      var latestAlert = snapshot.data!.docs.first;
                      _showEmergencyOverlay(
                        latestAlert.data() as Map<String, dynamic>,
                        latestAlert.id,
                      );
                    });
                    return IgnorePointer(
                      child: Container(color: Colors.red.withOpacity(0.1)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

            // MAIN ISSUE LIST UI
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (widget.role == 'head_admin')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'boys',
                                label: Text('Boys Hostel'),
                              ),
                              ButtonSegment(
                                value: 'girls',
                                label: Text('Girls Hostel'),
                              ),
                            ],
                            selected: {_currentHostelView},
                            onSelectionChanged: (val) => setState(
                                () => _currentHostelView = val.first),
                          ),
                        ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['all', 'pending', 'in_progress', 'resolved']
                              .map((status) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(status.toUpperCase()),
                                selected: _selectedStatus == status,
                                onSelected: (_) =>
                                    setState(() => _selectedStatus = status),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return Center(child: Text("Error: ${snapshot.error}"));
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                        return const Center(child: Text("No issues found."));

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var issue = doc.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                              title: Text(issue['title'] ?? 'No Title'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(issue['description'] ?? ''),
                                  if (widget.role != 'student') ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      "By: ${issue['studentName']} | Room: ${issue['roomNo']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                    if (issue['location'] != null) ...[
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade50,
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          elevation: 0,
                                        ),
                                        icon: const Icon(Icons.location_on, size: 18),
                                        label: const Text("VIEW SOS LOCATION"),
                                        onPressed: () {
                                          final String? mapUrl =
                                              issue['location']?['googleMapsUrl'];
                                          _openMap(mapUrl);
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                              trailing: (widget.role != 'student')
                                  ? PopupMenuButton<String>(
                                      onSelected: (val) =>
                                          _updateStatus(doc.id, val),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                            value: 'pending', child: Text("Pending")),
                                        const PopupMenuItem(
                                            value: 'in_progress', child: Text("In Progress")),
                                        const PopupMenuItem(
                                            value: 'resolved', child: Text("Resolved")),
                                      ],
                                      child: _StatusChip(status: issue['status']),
                                    )
                                  : _StatusChip(status: issue['status']),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: widget.role == 'student'
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 🚨 SOS BUTTON (Now uses the fetched assignedRoom)
                  FloatingActionButton.extended(
                    heroTag: "sos_btn",
                    onPressed: () => _handleSosTrigger(),
                    backgroundColor: Colors.red,
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    label: const Text(
                      "SOS EMERGENCY",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 12),

                  FloatingActionButton.extended(
                    heroTag: "issue_btn",
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateIssueScreen(
                          studentName: widget.name,
                          hostelType: widget.hostelType,
                          roomNo: assignedRoom,
                        ),
                      ),
                    ),
                    label: const Text("Report Issue"),
                    icon: const Icon(Icons.add),
                  ),
                ],
              )
            : null,
      );
    },
  );
}

  // ignore: unused_element
  Future<void> _launchMap(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error opening map: $e")));
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip({this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status == 'pending') color = Colors.orange;
    if (status == 'in_progress') color = Colors.blue;
    if (status == 'resolved') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        status?.toUpperCase() ?? 'PENDING',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

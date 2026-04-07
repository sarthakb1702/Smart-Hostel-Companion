import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class UserManagementScreen extends StatefulWidget {
  final String role;
  final String hostelType;

  const UserManagementScreen({
    super.key, 
    required this.role, 
    required this.hostelType
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = "";
  bool _showOnlyActive = true;

  // 1. Toggle student account active/inactive
  Future<void> _toggleAccess(String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': !currentStatus,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error toggling access: $e"))
        );
      }
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // 2. Room Assignment Dialog
  void _showAssignRoomDialog(String uid, String currentRoom, String studentName) {
    TextEditingController roomController = TextEditingController(text: currentRoom == 'Not Assigned' ? "" : currentRoom);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Assign Room: $studentName"),
        content: TextField(
          controller: roomController,
          decoration: const InputDecoration(
            labelText: "Official Room Number",
            hintText: "e.g., B-204",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'roomNo': roomController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            }, 
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  // 3. Detailed Student View (Bottom Sheet)
  void _showStudentDetails(Map<String, dynamic> studentData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(studentData['name'] ?? "Unknown", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Chip(label: Text("Room: ${studentData['roomNo'] ?? 'N/A'}"), backgroundColor: Colors.indigo.shade50),
              ],
            ),
            const Divider(),
            _buildDetailRow(Icons.bloodtype, "Blood Group", studentData['bloodGroup'] ?? "Unknown", Colors.red),
            _buildDetailRow(Icons.school, "Dept/Year", "${studentData['department']} (${studentData['year']})", Colors.indigo),
            _buildDetailRow(Icons.email, "Email", studentData['email'] ?? "N/A", Colors.grey),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(studentData['phone']),
                    icon: const Icon(Icons.phone),
                    label: const Text("Call Student"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(studentData['parentPhone']),
                    icon: const Icon(Icons.family_restroom),
                    label: const Text("Call Parent"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 15),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'head_admin') {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Student Directory"),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            bottom: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: "Boys Hostel"),
                Tab(text: "Girls Hostel"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildListContent('boys'),
              _buildListContent('girls'),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Student Directory"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: _buildListContent(widget.hostelType),
      );
    }
  }

  Widget _buildListContent(String targetHostel) {
    Query query = FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'student')
        .where('hostelType', isEqualTo: targetHostel);

    return Column(
      children: [
        // 🔎 Search and Filter Section
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search by Name or Room...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              Row(
                children: [
                  FilterChip(
                    label: const Text("Active Only"),
                    selected: _showOnlyActive,
                    onSelected: (val) => setState(() => _showOnlyActive = val),
                    selectedColor: Colors.indigo.shade100,
                  ),
                  const SizedBox(width: 10),
                  Text("Hostel: ${targetHostel.toUpperCase()}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        
        // 📜 Student List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              // Client-side filtering for Search and Active status
              var students = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                bool matchesSearch = (data['name'] ?? "").toString().toLowerCase().contains(_searchQuery) ||
                                     (data['roomNo'] ?? "").toString().toLowerCase().contains(_searchQuery);
                bool matchesStatus = _showOnlyActive ? (data['isActive'] ?? true) : true;
                return matchesSearch && matchesStatus;
              }).toList();

              if (students.isEmpty) {
                return Center(
                  child: Text(
                    targetHostel == 'girls' ? "No female students found." : "No male students found.",
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  var data = students[index].data() as Map<String, dynamic>;
                  String uid = students[index].id;
                  bool active = data['isActive'] ?? true;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      onTap: () => _showStudentDetails(data),
                      leading: CircleAvatar(
                        backgroundColor: active ? Colors.indigo.shade100 : Colors.grey.shade300,
                        child: Text(data['name'] != null ? data['name'][0].toUpperCase() : "?"),
                      ),
                      title: Text(data['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Room: ${data['roomNo'] ?? 'N/A'}\n${data['phone'] ?? ''}"),
                      trailing: Wrap(
                        spacing: 12,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.meeting_room, color: Colors.blue),
                            onPressed: () => _showAssignRoomDialog(uid, data['roomNo'] ?? 'Not Assigned', data['name']),
                          ),
                          Switch(
                            value: active,
                            activeThumbColor: Colors.green,
                            onChanged: (val) => _toggleAccess(uid, active),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
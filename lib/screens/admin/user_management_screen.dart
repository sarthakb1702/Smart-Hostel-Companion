import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // 2. Room Assignment Dialog
  void _showAssignRoomDialog(String uid, String currentRoom, String studentName) {
    TextEditingController roomController = TextEditingController(text: currentRoom);
    
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
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'roomNo': roomController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Room updated successfully!")),
                  );
                }
              } catch (e) {
                debugPrint("Error assigning room: $e");
              }
            }, 
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine which students to show
    Query query = FirebaseFirestore.instance.collection('users');

    if (widget.role == 'warden') {
      query = query
          .where('hostelType', isEqualTo: widget.hostelType)
          .where('role', isEqualTo: 'student');
    } else if (widget.role == 'head_admin') {
      // Head admin sees all students from both hostels
      query = query.where('role', isEqualTo: 'student');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Management"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading data"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No students found."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var userDoc = docs[index];
              var user = userDoc.data() as Map<String, dynamic>;
              
              String uid = userDoc.id;
              String name = user['name'] ?? 'Unknown';
              String room = user['roomNo'] ?? 'Not Assigned';
              bool active = user['isActive'] ?? true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: active ? Colors.indigo.shade100 : Colors.grey.shade300,
                    child: Icon(Icons.person, color: active ? Colors.indigo : Colors.grey),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "Room: $room\nHostel: ${user['hostelType'] ?? 'N/A'}",
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Room Button
                      IconButton(
                        icon: const Icon(Icons.meeting_room, color: Colors.blue),
                        onPressed: () => _showAssignRoomDialog(uid, room, name),
                      ),
                      // Access Control Switch
                      Switch(
                        value: active,
                        activeColor: Colors.green,
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
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'warden_guest_history_screen.dart';

class GuestRequestsScreen extends StatelessWidget {
  const GuestRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text("Guest Requests"),
  actions: [
    IconButton(
      icon: const Icon(Icons.history),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WardenHistoryScreen(),
          ),
        );
      },
    ),
  ],
),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('guest_entries')
.where('status', isEqualTo: 'pending')
.snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No guest requests found"));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
Text("🎓 Student: ${data['student_name'] ?? 'N/A'}"),
Text("🏠 Room: ${data['room_no'] ?? 'N/A'}"),
                      Text("👤 Name: ${data['name'] ?? ''}"),
                      Text("👥 Relation: ${data['relation'] ?? ''}"),
                      Text("📞 Phone: ${data['phone'] ?? ''}"),
                      Text("📍 Address: ${data['address'] ?? ''}"),
                      Text("🕒 In: ${data['in_time'] ?? ''}"),
                      Text("🕒 Out: ${data['out_time'] ?? ''}"),

                      const SizedBox(height: 8),

                      Text(
                        "Status: ${data['status']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: data['status'] == 'approved'
                              ? Colors.green
                              : data['status'] == 'rejected'
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 🔥 SHOW BUTTONS ONLY IF PENDING
                      if (data['status'] == 'pending')
                        Row(
                          children: [

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () {
                                updateStatus(doc.id, "approved");
                              },
                              child: const Text("Approve"),
                            ),

                            const SizedBox(width: 10),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                updateStatus(doc.id, "rejected");
                              },
                              child: const Text("Reject"),
                            ),
                          ],
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

  void updateStatus(String id, String status) {
    FirebaseFirestore.instance
        .collection('guest_entries')
        .doc(id)
        .update({'status': status});
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GatePassHistoryScreen extends StatelessWidget {
  const GatePassHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 1. Fetch User Role to decide the Query
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final String role = userData['role'] ?? 'student';

        return Scaffold(
          appBar: AppBar(
            title: Text(role == 'warden' ? "All Gate Passes" : "My Pass History"),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            // 🚀 THE LOGIC: 
            // If Warden -> Show everything. 
            // If Student -> Filter by their specific UID.
            stream: role == 'warden'
                ? FirebaseFirestore.instance
                    .collection('gate_passes')
                    .orderBy('outTime', descending: true)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('gate_passes')
                    .where('studentUid', isEqualTo: user?.uid)
                    .orderBy('outTime', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No records found."));

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  // Time Formatting
                  String outTime = data['outTime'] != null 
                      ? DateFormat('dd MMM, hh:mm a').format((data['outTime'] as Timestamp).toDate()) 
                      : "Pending...";
                  String inTime = data['inTime'] != null 
                      ? DateFormat('hh:mm a').format((data['inTime'] as Timestamp).toDate()) 
                      : "Still Out";

                  bool isActive = data['status'] == 'ACTIVE';

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.orange.shade100 : Colors.green.shade100,
                        child: Icon(
                          isActive ? Icons.exit_to_app : Icons.home,
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                      ),
                      title: Text(
                        role == 'warden' ? "${data['studentName']} (Room ${data['roomNo']})" : "To: ${data['destination']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (role == 'warden') Text("Destination: ${data['destination']}"),
                          Text("Out: $outTime"),
                          Text("In: $inTime", style: TextStyle(color: isActive ? Colors.red : Colors.grey)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.orange : Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['status'] ?? "CLOSED",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
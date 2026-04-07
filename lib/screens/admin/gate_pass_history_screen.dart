import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GatePassHistoryScreen extends StatelessWidget {
  final String role;
  final String hostelType;

  const GatePassHistoryScreen({
    super.key, 
    required this.role, 
    required this.hostelType
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'head_admin' ? "Global Gate Activity" : "Hostel Gate Pass Log"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: (() {
          Query q = FirebaseFirestore.instance.collection('gate_passes');

          // 🛡️ ROLE-BASED FILTERING
          // Only Head Admin sees everything. Warden only sees their specific hostel.
          if (role != 'head_admin') {
            q = q.where('hostelType', isEqualTo: hostelType.toLowerCase());
          }

          return q.orderBy('outTime', descending: true).snapshots();
        })(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              String status = data['status'] ?? 'ACTIVE';
              bool isActive = status == 'ACTIVE';

              // ⏱️ TIMESTAMP HANDLING (Prevents Null vs Num errors)
              DateTime? outTime = (data['outTime'] as Timestamp?)?.toDate();
              DateTime? inTime = (data['inTime'] as Timestamp?)?.toDate();

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), 
                  side: BorderSide(color: Colors.grey.shade200)
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.orange.shade50 : Colors.green.shade50,
                    child: Icon(
                      isActive ? Icons.directions_walk : Icons.home_work_outlined,
                      color: isActive ? Colors.orange : Colors.green,
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "${data['studentName'] ?? "Unknown Student"} (${data['roomNo'] ?? 'N/A'})", 
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _statusLabel(status),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Destination: ${data['destination'] ?? 'Not Specified'}", 
                           style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 4),
                      if (outTime != null)
                        Text("Left: ${DateFormat('hh:mm a, dd MMM').format(outTime)}", 
                             style: const TextStyle(fontSize: 12)),
                      if (inTime != null)
                        Text("Returned: ${DateFormat('hh:mm a, dd MMM').format(inTime)}", 
                             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                      if (isActive)
                        const Text("Currently Outside", 
                             style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
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

  Widget _statusLabel(String status) {
    bool isActive = status == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.orange : Colors.green),
      ),
      child: Text(
        isActive ? "OUT" : "RETURNED",
        style: TextStyle(
          color: isActive ? Colors.orange.shade900 : Colors.green.shade900, 
          fontSize: 9, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.door_front_door_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No Gate Pass records for this hostel.", 
                     style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
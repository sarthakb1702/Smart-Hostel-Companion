import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LeaveManagementScreen extends StatelessWidget {
  final String hostelType;
  final String? role;
  const LeaveManagementScreen({super.key, required this.hostelType, this.role});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("LEAVE MANAGEMENT"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: "Pending"),
              Tab(icon: Icon(Icons.history), text: "History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLeaveList(isHistory: false), // Sub-section 1: Pending
            _buildLeaveList(isHistory: true),  // Sub-section 2: Approved/Rejected
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveList({required bool isHistory}) {
    Query query = FirebaseFirestore.instance.collection('leave_applications');
    if (role != 'head_admin') {
      query = query.where('hostelType', isEqualTo: hostelType);
    }

    // Apply Filter based on Tab
    if (isHistory) {
      query = query.where('status', whereIn: ['approved', 'rejected']);
    } else {
      query = query.where('status', isEqualTo: 'pending');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(isHistory ? "No history found." : "No pending requests."),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildLeaveCard(doc.id, data, !isHistory);
          },
        );
      },
    );
  }

  Widget _buildLeaveCard(String docId, Map<String, dynamic> data, bool showActions) {
    DateTime start = (data['startDate'] as Timestamp).toDate();
    DateTime end = (data['endDate'] as Timestamp).toDate();
    String status = data['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['studentName'] ?? "Unknown", 
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                if (!showActions) _statusBadge(status), // Show status if in History tab
              ],
            ),
            Text("Room: ${data['roomNo']}", style: const TextStyle(color: Colors.indigo)),
            const Divider(),
            Text("Dates: ${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}"),
            Text("Reason: ${data['reason']}"),
            
            if (showActions) ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(docId, 'rejected'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text("REJECT"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(docId, 'approved'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text("APPROVE"),
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance
        .collection('leave_applications')
        .doc(docId)
        .update({'status': status, 'processedAt': FieldValue.serverTimestamp()});
  }

  Widget _statusBadge(String status) {
    Color color = status == 'approved' ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(status.toUpperCase(), 
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
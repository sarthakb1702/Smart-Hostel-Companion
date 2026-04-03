import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SosHistoryScreen extends StatelessWidget {
  final String hostelType;
  const SosHistoryScreen({super.key, required this.hostelType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("EMERGENCY LOGS"),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sos_alerts')
            .where('hostelType', isEqualTo: hostelType)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'active';
              DateTime time = (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: Icon(
                    status == 'active' ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: status == 'active' ? Colors.red : Colors.green,
                    size: 30,
                  ),
                  title: Text(
                    data['studentName'] ?? "Unknown Student",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${DateFormat('dd MMM, hh:mm a').format(time)} • Room ${data['roomNo'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow("Description", data['description'] ?? "No details provided"),
                          const SizedBox(height: 10),
                          _detailRow("Status", status.toUpperCase(), 
                              color: status == 'active' ? Colors.red : Colors.green),
                          if (status == 'active') ...[
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () => _resolveAlert(snapshot.data!.docs[index].id),
                                child: const Text("MARK AS RESOLVED / SAFE"),
                              ),
                            )
                          ]
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- LOGIC: Resolve Alert ---
  Future<void> _resolveAlert(String docId) async {
    await FirebaseFirestore.instance.collection('sos_alerts').doc(docId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- UI HELPERS ---
  Widget _detailRow(String label, String value, {Color color = Colors.black87}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No emergency alerts recorded.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
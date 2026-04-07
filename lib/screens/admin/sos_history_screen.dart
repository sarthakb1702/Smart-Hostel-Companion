import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SosHistoryScreen extends StatelessWidget {
  final String hostelType;
  final String? role;
  const SosHistoryScreen({super.key, required this.hostelType, this.role});

  @override
  Widget build(BuildContext context) {
    // 🛡️ Admin Check for UI elements
    final bool isAuthorizedStaff = role == 'warden' || role == 'head_admin';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("EMERGENCY LOGS"),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: (() {
          Query q = FirebaseFirestore.instance.collection('sos_alerts');
          
          // 🛡️ DATA ISOLATION: 
          // If not Head Admin, only show alerts for this specific building
          if (role != 'head_admin') {
            q = q.where('hostelType', isEqualTo: hostelType.toLowerCase().trim());
          }
          
          return q.orderBy('createdAt', descending: true).snapshots();
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
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String status = data['status'] ?? 'active';
              DateTime time = (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate();

              bool isActive = status == 'active';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isActive ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isActive ? Colors.red.shade100 : Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                      isActive ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: isActive ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(
                    data['studentName'] ?? "Unknown Student",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.red.shade900 : Colors.black87,
                    ),
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
                          _detailRow("Hostel Section", (data['hostelType'] ?? 'N/A').toString().toUpperCase()),
                          const SizedBox(height: 10),
                          _detailRow("Status", status.toUpperCase(), 
                              color: isActive ? Colors.red : Colors.green),
                          
                          // 🚨 ACTION BUTTONS: Only visible to Warden/Admin
                          if (isActive && isAuthorizedStaff) ...[
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                // 📍 TRACK BUTTON
                                if (data['location'] != null && data['location']['lat'] != 0.0)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red, 
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        final urlString = data['location']['googleMapsUrl'] ?? "";
                                        final url = Uri.parse(urlString);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      icon: const Icon(Icons.location_on),
                                      label: const Text("TRACK"),
                                    ),
                                  ),
                                if (data['location'] != null && data['location']['lat'] != 0.0)
                                  const SizedBox(width: 8),

                                // ✅ RESOLVE BUTTON (Only for Staff)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, 
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _resolveAlert(doc.id),
                                    icon: const Icon(Icons.check),
                                    label: const Text("MARK SAFE"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Message for students if they open an active alert
                          if (isActive && !isAuthorizedStaff)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                "🚨 This alert is active. Authorities have been notified.",
                                style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                            ),
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
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
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
          Text(
            "No active alerts for ${(hostelType).toUpperCase()} Hostel.", 
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
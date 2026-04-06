import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/parcel_service.dart';

class StudentParcelListScreen extends StatelessWidget {
  final String hostelType;
  final String? recipientName;
  const StudentParcelListScreen({super.key, required this.hostelType, required this.recipientName});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("My Parcels"),
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.outbox), text: "To Collect"),
              Tab(icon: Icon(Icons.history_edu), text: "Recently Picked Up"),
            ],
            indicatorColor: Colors.indigo,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildParcelList(uid, 'pending'),
            _buildParcelList(uid, 'collected'),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelList(String uid, String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: ParcelService().getStudentParcelsStream(uid, hostelType, status: status), 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
            child: ListView( 
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Icon(status == 'pending' ? Icons.outbox_rounded : Icons.check_circle_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 15),
                Center(
                  child: Text(
                    status == 'pending' ? "No pending parcels at the moment." : "No collection history.",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }

        final parcels = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: parcels.length,
            itemBuilder: (context, index) {
              final doc = parcels[index];
              final data = doc.data() as Map<String, dynamic>;
              
              String timeAgo = "Processing...";
              if (status == 'collected' && data['collectedAt'] != null) {
                final DateTime date = (data['collectedAt'] as Timestamp).toDate();
                timeAgo = "Collected: ${DateFormat('MMM dd, yyyy • hh:mm a').format(date)}";
              } else if (data['createdAt'] != null) {
                final DateTime date = (data['createdAt'] as Timestamp).toDate();
                timeAgo = "Arrived: ${DateFormat('MMM dd, yyyy • hh:mm a').format(date)}";
              }

              return Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.indigoAccent,
                            child: Icon(Icons.inventory_2, color: Colors.white),
                          ),
                          const SizedBox(width: 15),
                          
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        "📦 YOUR PARCEL",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: status == 'pending' ? Colors.orange.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: status == 'pending' ? Colors.orange.shade200 : Colors.green.shade200),
                                      ),
                                      child: Text(
                                        status == 'pending' ? "PENDING" : "COLLECTED",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'pending' ? Colors.orange.shade800 : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  data['parcelDescription'] ?? "No description provided",
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  timeAgo,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                if (status == 'pending') ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Please visit the Warden's desk with your ID to collect.",
                                    style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w500, 
                                      color: Colors.black87,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (status == 'pending') ...[
                        const Divider(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                               bool? confirm = await showDialog(
                                 context: context,
                                 builder: (context) => AlertDialog(
                                   title: const Text("Mark Received"),
                                   content: const Text("Did you physically collect this parcel?"),
                                   actions: [
                                     TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                                     ElevatedButton(
                                       onPressed: () => Navigator.pop(context, true), 
                                       child: const Text("Yes"),
                                     ),
                                   ],
                                 ),
                               );
                               if (confirm == true) {
                                 await ParcelService().markCollected(doc.id);
                               }
                            },
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            label: const Text("Mark as Received", style: TextStyle(color: Colors.green)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

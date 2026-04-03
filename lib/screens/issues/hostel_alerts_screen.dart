import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/alert_service.dart';

class HostelAlertsScreen extends StatelessWidget {
  final String hostelType;
  const HostelAlertsScreen({super.key, required this.hostelType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ensures clean white theme
      appBar: AppBar(
        title: const Text("Hostel Alerts", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: AlertService().getAlertsStream(hostelType.toLowerCase()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No official updates found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return _buildAlertCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> data) {
    bool isUrgent = data['isUrgent'] ?? false;
    DateTime time = (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badge(isUrgent), // 🚨 Displays "URGENT NOTICE" or "NOTICE"
              Text(
                DateFormat('jm').format(time),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['title'] ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            data['description'] ?? '',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
          ),
          // 📝 Removed the "Warden Office" label as requested
        ],
      ),
    );
  }

  Widget _badge(bool isUrgent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isUrgent ? "URGENT NOTICE" : "NOTICE", // 👈 EXACT TEXT UPDATED
        style: TextStyle(
          color: isUrgent ? Colors.red.shade700 : Colors.blue.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
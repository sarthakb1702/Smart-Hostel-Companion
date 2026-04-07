import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/alert_service.dart';
import '../../utils/app_colours.dart';

class StudentAlertsTab extends StatelessWidget {
  final String hostelType;
  const StudentAlertsTab({super.key, required this.hostelType});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔹 HEADER
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hostel Alerts",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 5),
                  Text("Official updates from the Warden",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications,
                    color: AppColors.primary),
              )
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 🔹 ALERT LIST
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: AlertService().getAlertsStream(hostelType),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No hostel alerts.", style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var alertData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final String title = alertData['title'] ?? 'Notice';
                  final String desc = alertData['description'] ?? '';
                  final Timestamp? timestamp = alertData['createdAt'] as Timestamp?;
                  final bool isUrgent = alertData['isUrgent'] ?? false;
                  
                  String formattedTime = "Unknown Date";
                  if (timestamp != null) {
                    DateTime date = timestamp.toDate();
                    DateTime now = DateTime.now();
                    if (date.year == now.year && date.month == now.month && date.day == now.day) {
                      formattedTime = "Today at ${DateFormat('hh:mm a').format(date)}";
                    } else {
                      formattedTime = DateFormat('dd MMM, hh:mm a').format(date);
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 TAG + TIME
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isUrgent ? Colors.red : Colors.blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isUrgent ? "Urgent" : "Notice",
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            Text(formattedTime, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),

                        const SizedBox(height: 8),

                        Text(desc, style: const TextStyle(color: AppColors.textSecondary)),
                        
                        const SizedBox(height: 12),

                        Row(
                          children: const [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text("W", style: TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                            SizedBox(width: 8),
                            Text("Warden Office",
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

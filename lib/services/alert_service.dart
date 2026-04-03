import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AlertService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> sendAlert({
    required String title,
    required String description,
    required bool isUrgent,
    required String hostelType,
  }) async {
    // 1. Save to Database
    await _db.collection('hostel_alerts').add({
      'title': title,
      'description': description,
      'isUrgent': isUrgent,
      'hostelType': hostelType.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Trigger the Broadcast Notification
    // Ensure the topic matches what we used in login (e.g., boys_hostel)
    await NotificationService.sendTopicNotification(
      topic: "${hostelType.toLowerCase()}_hostel",
      title: isUrgent ? "🚨 URGENT: $title" : "📢 Notice: $title",
      body: description,
    );
  }

  // Stream for the UI list
  Stream<QuerySnapshot> getAlertsStream(String hostelType) {
    return _db
        .collection('hostel_alerts')
        .where('hostelType', isEqualTo: hostelType.toLowerCase())
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
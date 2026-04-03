import 'package:cloud_firestore/cloud_firestore.dart';

class HostelAlert {
  final String id, title, description, hostelType;
  final bool isUrgent;
  final DateTime createdAt;

  HostelAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.isUrgent,
    required this.createdAt,
    required this.hostelType,
  });

  // Factory to convert Firestore data to a usable Object
  factory HostelAlert.fromMap(Map<String, dynamic> data, String docId) {
    return HostelAlert(
      id: docId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isUrgent: data['isUrgent'] ?? false,
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      hostelType: data['hostelType'] ?? 'boys',
    );
  }
}
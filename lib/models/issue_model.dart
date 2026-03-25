import 'package:cloud_firestore/cloud_firestore.dart';

class IssueModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String createdByUid;
  final String createdByName;
  final String hostelType;
  final DateTime createdAt;

  IssueModel({
    required this.id, required this.title, required this.description,
    required this.category, required this.priority, required this.status,
    required this.createdByUid, required this.createdByName,
    required this.hostelType, required this.createdAt,
  });

  factory IssueModel.fromFirestore(DocumentSnapshot doc) {
    var d = doc.data() as Map<String, dynamic>;
    return IssueModel(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? 'General',
      priority: d['priority'] ?? 'medium',
      status: d['status'] ?? 'pending',
      createdByUid: d['createdByUid'] ?? '',
      createdByName: d['createdByName'] ?? 'Unknown',
      hostelType: d['hostelType'] ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }
}
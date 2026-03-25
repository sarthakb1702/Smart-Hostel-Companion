import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/issue_model.dart';

class IssueService {
  final _db = FirebaseFirestore.instance;

  // Create standard maintenance issue
  Future<void> createIssue({
    required String title,
    required String description,
    required String category,
    required String priority,
    required String uid,
    required String name,
    required String hostel,
  }) async {
    await _db.collection('issues').add({
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': 'pending',
      'createdByUid': uid,
      'createdByName': name,
      'hostelType': hostel,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // SOS Alert Logic
  Future<void> triggerSOS({
    required String uid,
    required String name,
    required String hostel,
  }) async {
    await _db.collection('sos_alerts').add({
      'studentUid': uid,
      'studentName': name,
      'hostelType': hostel,
      'timestamp': FieldValue.serverTimestamp(),
      'isResolved': false,
    });
  }

  // Stream for Students (Only their own)
  Stream<List<IssueModel>> getMyIssues(String uid) {
    return _db.collection('issues')
        .where('createdByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snaps) => snaps.docs.map((d) => IssueModel.fromFirestore(d)).toList());
  }

  // Stream for Wardens (Only their hostel)
  Stream<List<IssueModel>> getHostelIssues(String hostel) {
    return _db.collection('issues')
        .where('hostelType', isEqualTo: hostel)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snaps) => snaps.docs.map((d) => IssueModel.fromFirestore(d)).toList());
  }
}
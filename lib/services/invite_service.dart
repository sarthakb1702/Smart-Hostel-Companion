import 'package:cloud_firestore/cloud_firestore.dart';

class InviteService {
  final _db = FirebaseFirestore.instance;

  Future<void> createInvite({
    required String email,
    required String role,
    required String hostelType,
    required String phone,
    required String createdByUid,
  }) async {
    await _db.collection('invites').doc(email.toLowerCase()).set({
      'email': email.toLowerCase(),
      'role': role,
      'hostelType': hostelType,
      'phone': phone,
      'isUsed': false,
      'createdBy': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot?> checkInvite(String email) async {
    return await _db.collection('invites').doc(email.toLowerCase()).get();
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class HousekeepingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📡 Stream for Students: Gets the latest active cleaning event
  Stream<QuerySnapshot> getLatestEventStream(String hostelType) {
    return _db
        .collection('housekeeping_events')
        .where('hostelType', isEqualTo: hostelType.toLowerCase())
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  // 📝 For Students: Submit rating and optional comment
  Future<void> submitFeedback({
    required String eventId,
    required String uid,
    required int roomRating,
    required int bathroomRating,
    String? comment,
  }) async {
    await _db.collection('housekeeping_events').doc(eventId).update({
      'ratings.$uid': {
        'room': roomRating,
        'bathroom': bathroomRating,
        'comment': comment ?? "",
        'timestamp': FieldValue.serverTimestamp(),
      }
    });
  }

  // 🚀 For Wardens: Start a new cleaning event
  Future<void> startCleaningEvent({
    required String hostelType,
    required String description,
  }) async {
    await _db.collection('housekeeping_events').add({
      'hostelType': hostelType.toLowerCase(),
      'description': description,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'ratings': {},
    });
  }

  // 📊 For Wardens: Get all completed cleaning sessions for analytics
  Stream<QuerySnapshot> getCompletedCleaningsStream(String hostelType, {required String? role}) {
    Query q = _db.collection('housekeeping_events');
    
    // Filter by hostel unless it's a global admin
    if (role != 'head_admin') {
      q = q.where('hostelType', isEqualTo: hostelType.toLowerCase());
    }
    
    return q.orderBy('createdAt', descending: true).snapshots();
  }
}
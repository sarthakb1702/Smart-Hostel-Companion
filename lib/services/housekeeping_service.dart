import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';

class HousekeepingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> startCleaningEvent({
    required String hostelType,
    required String description,
  }) async {
    await _db.collection('housekeeping_events').add({
      'hostelType': hostelType.toLowerCase(),
      'description': description,
      'status': 'active',
      'cleaningDate': FieldValue.serverTimestamp(),
      'ratings': {}, 
    });

    await NotificationService.sendTopicNotification(
      topic: "${hostelType.toLowerCase()}_hostel",
      title: "✨ Cleaning Completed!",
      body: "Please rate today's housekeeping on your dashboard.",
    );
  }

  Future<void> submitFeedback({
    required String eventId,
    required String uid,
    required int roomRating,
    required int bathroomRating,
  }) async {
    double averageRating = (roomRating + bathroomRating) / 2.0;

    await _db.collection('housekeeping_events').doc(eventId).set({
      'ratings': {
        uid: {
          'roomRating': roomRating,
          'bathroomRating': bathroomRating,
          'average': averageRating,
          'timestamp': DateTime.now(), // Use DateTime.now() since nested ServerTimestamps in maps can sometimes act up if heavily modified
        }
      }
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getActiveEventsStream(String hostelType) {
    return _db.collection('housekeeping_events')
        .where('hostelType', isEqualTo: hostelType.toLowerCase())
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Stream<QuerySnapshot> getLatestEventStream(String hostelType) {
    return _db.collection('housekeeping_events')
        .where('hostelType', isEqualTo: hostelType.toLowerCase())
        .orderBy('cleaningDate', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot> getCompletedCleaningsStream(String hostelType, {String? role}) {
    Query query = _db.collection('housekeeping_events');
    if (role != 'head_admin') {
      query = query.where('hostelType', isEqualTo: hostelType.toLowerCase());
    }
    return query.orderBy('cleaningDate', descending: true).snapshots();
  }
}

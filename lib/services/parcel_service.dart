import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class ParcelService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addParcel({
    required String recipientUid,
    required String recipientName,       
    required String hostelType,
    String? parcelDescription,
    String? fcmToken,
  }) async {
    if (recipientUid == "UNKNOWN" || recipientUid.isEmpty) {
      throw Exception("Recipient UID must be a valid strictly-selected student UID.");
    }

    // Add natively to Firestore handling the explicit variable structures without Images
    await _db.collection('parcels').add({
      'recipientUid': recipientUid, 
      'recipientName': recipientName,            
      'parcelDescription': parcelDescription ?? "No description provided",
      'hostelType': hostelType.toLowerCase(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Conditional Push Notifications Route
    if (fcmToken != null) {
      await NotificationService.sendPrivateNotification(
        token: fcmToken,
        title: "📦 New Parcel Arrived!",
        body: "Please collect it from the Warden office.",
        type: "parcel_update",
      );
    }
  }

  Future<void> markCollected(String parcelId) async {
    await _db.collection('parcels').doc(parcelId).update({
      'status': 'collected',
      'collectedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getWardenParcelsStream(String hostelType, {String status = 'pending', String? role}) {
    Query query = _db.collection('parcels').where('status', isEqualTo: status);
    if (role != 'head_admin') {
      query = query.where('hostelType', isEqualTo: hostelType.toLowerCase());
    }
        
    if (status == 'collected') {
      // For History tab, order by collected time
      query = query.orderBy('collectedAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot> getStudentParcelsStream(String uid, String hostelType, {String status = 'pending'}) {
    Query query = _db
        .collection('parcels')
        .where('hostelType', isEqualTo: hostelType.toLowerCase())
        .where('status', isEqualTo: status)
        .where('recipientUid', isEqualTo: uid);
        
    if (status == 'collected') {
      query = query.orderBy('collectedAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    return query.snapshots();
  }
}

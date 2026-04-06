import 'dart:convert';
import 'package:flutter/services.dart'; // Required for rootBundle
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:googleapis_auth/auth_io.dart'; // Required for OAuth2

class SosService {
  static Future<void> triggerSos({
    required String name,
    required String hostel,
    String? description,
    required String recipientName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1. Fetch the OFFICIAL room from the users collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final assignedRoom = userDoc.data()?['roomNo'] ?? "Unassigned";

    // 2. Get GPS Location
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 3. Send Alert to Firestore (For the Warden's Web/Mobile List)
    await FirebaseFirestore.instance.collection('sos_alerts').add({
      'studentName': name,
      'hostelType': hostel,
      'roomNo': assignedRoom,
      'description': description ?? "No additional info",
      'recipientName': recipientName,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'location': {
        'lat': position.latitude,
        'lng': position.longitude,
        'googleMapsUrl': "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}",
      },
    });

    // 4. Trigger the Automatic Push Notification
    await _sendPushNotificationToWarden(hostel, name,description);
  }

  static Future<void> _sendPushNotificationToWarden(String hostel, String studentName, String? description) async {
  var wardens = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'warden')
      .where('hostelType', isEqualTo: hostel)
      .get();

  for (var doc in wardens.docs) {
    String? token = doc.data()['fcmToken'];
    if (token != null) {
      // 🚨 Pass the description here
      await _sendHttpRequest(token, studentName, hostel, description);
    }
  }
}

  // --- MODERN FCM HTTP v1 LOGIC ---

  static Future<String> _getAccessToken() async {
    // This reads the JSON file you put in your assets folder
    final String response = await rootBundle.loadString('assets/service-account.json');
    final data = json.decode(response);

    final credentials = ServiceAccountCredentials.fromJson(data);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await clientViaServiceAccount(credentials, scopes);
    return client.credentials.accessToken.data;
  }

  static Future<void> _sendHttpRequest(String token, String studentName, String hostel, String? description) async {
  try {
    final String accessToken = await _getAccessToken();
    const String projectId = 'smart-hostel-companion';

    final String alertBody = (description != null && description.isNotEmpty) 
        ? "HELP: $description" 
        : "Emergency SOS triggered! Check location.";

    // ignore: unused_local_variable
    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'message': {
          'token': token,
          'notification': {
            'title': '🚨 SOS: $studentName',
            'body': alertBody,
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'high_importance_channel', // 🚨 Must match your main.dart
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'sound': 'default',
              'default_vibrate_timings': false, // 🚨 Disable default to use ours
              'vibrate_timings': ["0s", "1s", "0.5s", "1s", "0.5s", "1s"], // Pulse pattern
              'color': '#FF0000', // Red icon for emergency
            },
          },
        },
      }),
    );
  } catch (e) {
    print("Vibration Error: $e");
  }
}
}
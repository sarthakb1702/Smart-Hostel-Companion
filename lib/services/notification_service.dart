import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static const String _projectId = 'smart-hostel-companion';

  // 🛡️ AUTH LOGIC: Uses your assets/service-account.json
  static Future<String> _getAccessToken() async {
    final String response = await rootBundle.loadString('assets/service-account.json');
    final data = json.decode(response);
    final credentials = ServiceAccountCredentials.fromJson(data);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await clientViaServiceAccount(credentials, scopes);
    return client.credentials.accessToken.data;
  }

  // 🔔 Subscribe student to their hostel topic
  static Future<void> subscribeToHostel(String hostelType) async {
    try {
      String topic = "${hostelType.toLowerCase()}_hostel";
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint("✅ Subscribed to topic: $topic");
    } catch (e) {
      debugPrint("❌ Subscription Error: $e");
    }
  }

  // 📢 BROADCAST: For Hostel Alerts (Topic-based)
  static Future<void> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
  }) async {
    try {
      final String accessToken = await _getAccessToken();
      
      await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'topic': topic, 
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'type': 'hostel_alert', // 👈 Used for navigation logic
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'high_importance_channel',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'color': '#3F51B5', 
              },
            },
          },
        }),
      );
    } catch (e) {
      debugPrint("Alert Notification Error: $e");
    }
  }

  // 👤 PRIVATE: For Leave Status/Maintenance (Token-based)
  static Future<void> sendPrivateNotification({
    required String token,
    required String title,
    required String body,
    String type = 'private_update', // Default type
  }) async {
    try {
      final String accessToken = await _getAccessToken();
      await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {'title': title, 'body': body},
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'type': type,
            },
            'android': {
              'notification': {
                'channel_id': 'high_importance_channel',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            },
          },
        }),
      );
    } catch (e) {
      debugPrint("Private Notification Error: $e");
    }
  }
}
import 'package:flutter/foundation.dart'; 
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';

class NotificationService {
  static const String _projectId = 'smart-hostel-companion';

  static Future<String> _getAccessToken() async {
    final String response = await rootBundle.loadString('assets/service-account.json');
    final data = json.decode(response);
    final credentials = ServiceAccountCredentials.fromJson(data);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await clientViaServiceAccount(credentials, scopes);
    return client.credentials.accessToken.data;
  }

  static Future<void> subscribeToHostel(String hostelType, {String? role}) async {
    if (kIsWeb) return; 
    try {
      String hostelTopic = "${hostelType.toLowerCase()}_hostel";
      await FirebaseMessaging.instance.subscribeToTopic(hostelTopic);
      if (role == 'warden' || role == 'head_admin') {
        await FirebaseMessaging.instance.subscribeToTopic('wardens');
      }
      if (role == 'head_admin') {
        await FirebaseMessaging.instance.subscribeToTopic('head_admins');
      }
    } catch (e) {
      debugPrint("Subscription Error: $e");
    }
  }

  static Future<void> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? extraData,
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
            'notification': {'title': title, 'body': body},
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'type': extraData?['type'] ?? 'hostel_alert', 
              ...?extraData,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'high_importance_channel',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'color': (extraData?['type'] == 'sos_alert') ? '#FF0000' : '#3F51B5', 
              },
            },
          },
        }),
      );
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }

  static Future<void> sendGatePassNotification(String name, String destination) async {
    return sendTopicNotification(
      topic: 'wardens',
      title: "🚪 New Gate Pass: $name",
      body: "Leaving for $destination.",
      extraData: {'type': 'gate_pass'}
    );
  }

  static Future<void> sendPrivateNotification({
    required String token,
    required String title,
    required String body,
    String type = 'private_update',
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
            'data': {'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'type': type},
            'android': {
              'notification': {
                'channel_id': 'high_importance_channel',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            },
          }
        }),
      );
    } catch (e) {
      debugPrint("Private Notification Error: $e");
    }
  }
}
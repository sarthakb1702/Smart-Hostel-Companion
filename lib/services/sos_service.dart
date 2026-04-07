// ignore_for_file: unnecessary_cast, unused_import

import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';

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
    final data = userDoc.data() as Map<String, dynamic>?;
    final assignedRoom = data?['roomNo'] ?? "Unassigned";

    // 🛡️ 2. SAFE GPS LOCATION FETCHING
    Map<String, dynamic> locationData = {
      'lat': 0.0,
      'lng': 0.0,
      'googleMapsUrl': "Location Not Available",
    };

    try {
      Position? position = await _determinePosition();
      if (position != null) {
        locationData = {
          'lat': position.latitude,
          'lng': position.longitude,
          // ✅ FIXED: Added '$' for proper string interpolation
          'googleMapsUrl': "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}",
        };
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    }

    // 3. Send Alert to Firestore
    await FirebaseFirestore.instance.collection('sos_alerts').add({
      'studentUid': uid,
      'studentName': name,
      'hostelType': hostel.toLowerCase(),
      'roomNo': assignedRoom,
      'description': description ?? "No additional info",
      'recipientName': recipientName,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'location': locationData,
    });

    // 4. Trigger the Automatic Push Notification
    String alertBody = description ?? 'Emergency Alert!';
    if (locationData['lat'] != 0.0) {
      alertBody += "\n📍 Location: Tap to view map";
    }

    // 🎯 TARGETED TOPIC: Ensures only the relevant warden gets it
    String topicName = 'warden_${hostel.toLowerCase().trim()}';
    
    debugPrint("🚀 Sending SOS to topic: $topicName");

    await NotificationService.sendTopicNotification(
      topic: topicName, 
      title: '🚨 SOS: $name ($assignedRoom)', 
      body: alertBody,
      extraData: {
        'type': 'sos_alert',
        'lat': locationData['lat'].toString(),
        'lng': locationData['lng'].toString(),
        'mapsUrl': locationData['googleMapsUrl'],
        'hostel': hostel.toLowerCase(),
      }
    );
  }

  // 🛡️ HELPER: Handles the Permission "Handshake"
  static Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS Services are disabled.");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10), 
    );
  }
}
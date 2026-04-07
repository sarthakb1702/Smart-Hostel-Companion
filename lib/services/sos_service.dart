import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:googleapis_auth/auth_io.dart';
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
          'googleMapsUrl': "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}",
        };
      }
    } catch (e) {
      print("Location Error: $e");
      // Fallback: We proceed without location so the SOS isn't blocked by a crash
    }

    // 3. Send Alert to Firestore
    await FirebaseFirestore.instance.collection('sos_alerts').add({
      'studentName': name,
      'hostelType': hostel,
      'roomNo': assignedRoom,
      'description': description ?? "No additional info",
      'recipientName': recipientName,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'location': locationData,
    });

    // 4. Trigger the Automatic Push Notification via Centralized NotificationService
    String alertBody = description ?? 'Emergency Alert!';
    if (locationData['lat'] != 0.0) {
      alertBody += "\n📍 Location: ${locationData['googleMapsUrl']}";
    }

    await NotificationService.sendTopicNotification(
      topic: 'wardens', 
      title: '🚨 SOS: $name ($assignedRoom)', 
      body: alertBody,
      extraData: {
        'type': 'sos_alert',
        'lat': locationData['lat'].toString(),
        'lng': locationData['lng'].toString(),
        'mapsUrl': locationData['googleMapsUrl'],
      }
    );
  }

  // 🛡️ HELPER: Handles the Permission "Handshake" with Android
  static Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5), // Don't hang forever if GPS is weak
    );
  }
}
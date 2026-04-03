import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'invite_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final InviteService _inviteService = InviteService();

  /// This method handles the entire signup process:
  /// 1. Verifies the invite exists and isn't used.
  /// 2. Creates the Auth account.
  /// 3. Creates the Firestore profile.
  /// 4. Marks the invite as used.
  Future<void> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // 1. Check if the invite exists
      var inviteDoc = await _inviteService.checkInvite(email);

      if (inviteDoc == null || !inviteDoc.exists) {
        throw "No valid invitation found for this email.";
      }

      // 2. Cast data to Map so we can access keys like ['isUsed']
      var inviteData = inviteDoc.data() as Map<String, dynamic>;

      if (inviteData['isUsed'] == true) {
        throw "This invitation has already been used.";
      }

      // 3. Create the User in Firebase Authentication
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password,
      );

      // 4. Create the User Profile in Firestore
      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email.toLowerCase().trim(),
        'role': inviteData['role'],
        'hostelType': inviteData['hostelType'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Mark the invite as used
      await inviteDoc.reference.update({'isUsed': true});
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Authentication failed.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> loginUser(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.toLowerCase().trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Function to Register a Student and Create their Profile
  Future<void> signUpStudent({
    required String email,
    required String password,
    required String name,
    required String hostel,
  }) async {
    try {
      // 1. Capture the 'UserCredential' 🚨 THIS IS THE KEY
      UserCredential result = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2. Get the actual user object from that result
      User? user = result.user;

      // 3. Use 'user!.uid' to create the profile document
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'role': 'student',
          'hostelType': hostel,
          'roomNo': 'Pending',
          'isProfileComplete': false, // 🚩 The new flag we added!
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateWardenToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission (Required for Android 13+ and iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();

      if (token != null) {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
        });
        print("🚀 Warden Token Saved: $token");
      }
    }
  }
}

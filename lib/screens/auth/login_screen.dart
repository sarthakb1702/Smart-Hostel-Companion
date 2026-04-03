import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🚨 Added
import '../../services/notification_service.dart'; // 🚨 Ensure this import is correct

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      UserCredential creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(creds.user!.uid)
          .get();

      if (!userDoc.exists) throw "User profile not found.";

      // Check account status
      if (userDoc.get('isActive') == false) {
        await FirebaseAuth.instance.signOut();
        throw "Access Denied: Your account has been deactivated.";
      }

      // --- 🚨 NEW NOTIFICATION LOGIC START 🚨 ---
      
      // 1. Get the device's unique FCM Token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      
      // 2. Save token to Firestore for private notifications (Leave/Maintenance)
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(creds.user!.uid)
            .update({'fcmToken': fcmToken});
      }

      // 3. Subscribe to the specific Hostel Topic for broadcast alerts
      String hostelType = userDoc.get('hostelType') ?? "boys"; // Default to boys if empty
      await NotificationService.subscribeToHostel(hostelType);

      // --- 🚨 NEW NOTIFICATION LOGIC END 🚨 ---

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 30),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _handleLogin, child: const Text("Login")),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/signup'), child: const Text("Create Account"))
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    // 1. Basic Validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Verify Invitation exists and is unused
      var inviteRef = FirebaseFirestore.instance.collection('invites').doc(email);
      var inviteDoc = await inviteRef.get();

      if (!inviteDoc.exists) {
        throw "This email hasn't been invited to the system. Please contact the Warden.";
      }
      
      if (inviteDoc['isUsed'] == true) {
        throw "This invitation has already been used to create an account.";
      }

      // 3. Create Auth User in Firebase Authentication
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      // 4. Create User Profile Document in Firestore
      // We pull 'role' and 'hostelType' directly from the Invitation record
      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'uid': userCred.user!.uid,
        'name': name,
        'email': email,
        'role': inviteDoc['role'], 
        'hostelType': inviteDoc['hostelType'], 
        'roomNo': 'Not Assigned',      // ✅ Added: Default room for Warden to update
        'isActive': true,              // ✅ Added: Active by default
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Mark Invite as Used so it can't be used again
      await inviteRef.update({'isUsed': true});

      // 6. Success! Navigate to RoleHandler
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }

    } on FirebaseAuthException catch (e) {
      String msg = "Authentication failed";
      if (e.code == 'email-already-in-use') msg = "Account already exists for this email.";
      if (e.code == 'invalid-email') msg = "The email address is not valid.";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      appBar: AppBar(
        title: const Text("Register Student"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.app_registration, size: 80, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text(
                "Join Smart Hostel",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Enter your details to activate your account"),
              const SizedBox(height: 30),
              
              TextField(
                controller: _nameController, 
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _emailController, 
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Invited Email Address",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _passwordController, 
                obscureText: true, 
                decoration: const InputDecoration(
                  labelText: "Create Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              
              const SizedBox(height: 30),
              
              _isLoading 
                ? const CircularProgressIndicator() 
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleSignup,
                      child: const Text("ACTIVATE ACCOUNT", style: TextStyle(fontSize: 16)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SendInviteScreen extends StatefulWidget {
  final String role, hostelType; 
  const SendInviteScreen({super.key, required this.role, required this.hostelType});

  @override
  State<SendInviteScreen> createState() => _SendInviteScreenState();
}

class _SendInviteScreenState extends State<SendInviteScreen> {
  final _emailController = TextEditingController();
  late String _selectedHostel;
  String _selectedRole = 'student';

  @override
  void initState() {
    super.initState();
    _selectedHostel = widget.role == 'warden' ? widget.hostelType : 'boys';
  }

  Future<void> _send() async {
    String email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('invites').doc(email).set({
        'email': email, //
        'role': _selectedRole, //
        'hostelType': _selectedHostel, //
        'isUsed': false, //
        'createdAt': FieldValue.serverTimestamp(), //
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send Invite")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            if (widget.role == 'head_admin') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                items: ['student', 'warden'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedHostel,
                items: ['boys', 'girls'].map((h) => DropdownMenuItem(value: h, child: Text(h.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _selectedHostel = val!),
              ),
            ] else 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text("Inviting to: ${widget.hostelType.toUpperCase()} HOSTEL"),
              ),
            ElevatedButton(onPressed: _send, child: const Text("SEND INVITE")),
          ],
        ),
      ),
    );
  }
}
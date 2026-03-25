import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateIssueScreen extends StatefulWidget {
  final String studentName;
  final String hostelType;
  final String roomNo;

  const CreateIssueScreen({
    super.key,
    required this.studentName,
    required this.hostelType,
    required this.roomNo,
  });

  @override
  State<CreateIssueScreen> createState() => _CreateIssueScreenState();
}

class _CreateIssueScreenState extends State<CreateIssueScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // 🏠 This controller will handle the Room Number display
  late TextEditingController _roomController;

  @override
  void initState() {
    super.initState();
    // Initialize with the room number passed from the previous screen
    _roomController = TextEditingController(text: widget.roomNo);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _submitIssue() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;

        // Save the issue to Firestore
        await FirebaseFirestore.instance.collection('issues').add({
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'roomNo': widget.roomNo, // Uses the official room passed in
          'studentName': widget.studentName,
          'hostelType': widget.hostelType,
          'status': 'pending',
          'createdByUid': user?.uid, // Using Uid for consistency with your query
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Issue reported successfully!")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error reporting issue: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Issue")),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ISSUE TITLE
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Issue Title",
                  hintText: "e.g., Fan not working",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) =>
                    (val == null || val.isEmpty) ? "Please enter a title" : null,
              ),
              const SizedBox(height: 20),

              // 2. ROOM NUMBER (Locked/Read-Only)
              TextFormField(
                controller: _roomController,
                readOnly: true, // 🔒 Student cannot change their assigned room
                decoration: InputDecoration(
                  labelText: "Your Assigned Room",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.meeting_room),
                  filled: true,
                  fillColor: Colors.grey.shade100, // Visual hint it's locked
                  helperText: "This is your official assigned room.",
                ),
              ),
              const SizedBox(height: 20),

              // 3. DETAILED DESCRIPTION
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: "Detailed Description",
                  hintText: "Describe the problem in detail...",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
                validator: (val) => (val == null || val.isEmpty)
                    ? "Please provide more details"
                    : null,
              ),
              const SizedBox(height: 30),

              // 4. SUBMIT BUTTON
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitIssue,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "SUBMIT COMPLAINT",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
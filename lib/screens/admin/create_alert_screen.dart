import 'package:flutter/material.dart';
import '../../services/alert_service.dart';

class CreateAlertScreen extends StatefulWidget {
  final String hostelType; // Pass 'boys' or 'girls' from Warden's profile
  const CreateAlertScreen({super.key, required this.hostelType});

  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isUrgent = false;
  bool _isLoading = false;

  void _handleSendAlert() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // This calls the AlertService which handles both Firestore and FCM
      await AlertService().sendAlert(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        isUrgent: _isUrgent,
        hostelType: widget.hostelType,
      );

      if (mounted) {
        Navigator.pop(context); // Go back to dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alert broadcasted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Hostel Alert")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                hintText: "e.g., Water Supply Timing",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Message",
                hintText: "Describe the update for students...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text("Mark as Urgent"),
              subtitle: const Text("Adds a red badge and urgent prefix"),
              value: _isUrgent,
              activeColor: Colors.red,
              onChanged: (val) => setState(() => _isUrgent = val),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSendAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("BROADCAST TO STUDENTS", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
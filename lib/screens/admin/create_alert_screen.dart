import 'package:flutter/material.dart';
import '../../services/alert_service.dart';

class CreateAlertScreen extends StatefulWidget {
  final String hostelType; // Pass 'boys' or 'girls' from Warden's profile
  final String? alertId;
  final String? existingTitle;
  final String? existingDescription;
  final bool? existingIsUrgent;

  const CreateAlertScreen({
    super.key, 
    required this.hostelType,
    this.alertId,
    this.existingTitle,
    this.existingDescription,
    this.existingIsUrgent,
  });

  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late bool _isUrgent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingTitle ?? "");
    _descController = TextEditingController(text: widget.existingDescription ?? "");
    _isUrgent = widget.existingIsUrgent ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

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
      if (widget.alertId != null) {
        await AlertService().updateAlert(
          alertId: widget.alertId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          isUrgent: _isUrgent,
          hostelType: widget.hostelType,
        );
      } else {
        await AlertService().sendAlert(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          isUrgent: _isUrgent,
          hostelType: widget.hostelType,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Go back to dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.alertId != null ? "Alert updated successfully!" : "Alert broadcasted successfully!")),
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
      appBar: AppBar(title: Text(widget.alertId != null ? "Edit Hostel Alert" : "New Hostel Alert")),
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
              activeThumbColor: Colors.red,
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
                    : Text(widget.alertId != null ? "UPDATE ALERT" : "BROADCAST TO STUDENTS", style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
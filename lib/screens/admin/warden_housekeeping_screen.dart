// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/housekeeping_service.dart';

class WardenHousekeepingScreen extends StatefulWidget {
  final String hostelType;
  final String? role;
  const WardenHousekeepingScreen({super.key, required this.hostelType, this.role});

  @override
  State<WardenHousekeepingScreen> createState() => _WardenHousekeepingScreenState();
}

class _WardenHousekeepingScreenState extends State<WardenHousekeepingScreen> {
  final HousekeepingService _service = HousekeepingService();
  final TextEditingController _descController = TextEditingController();
  bool _isLogging = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _showLogDialog() {
    _descController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Start Cleaning Event"),
            content: TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: "Description",
                hintText: "e.g. Weekly Deep Clean",
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
              ElevatedButton(
                onPressed: _isLogging ? null : () async {
                  if (_descController.text.trim().isEmpty) return;
                  setDialogState(() => _isLogging = true);
                  try {
                    await _service.startCleaningEvent(
                      hostelType: widget.hostelType,
                      description: _descController.text.trim(),
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event Broadcasted!")));
                    }
                  } finally {
                    if (mounted) setDialogState(() => _isLogging = false);
                  }
                },
                child: const Text("START"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Housekeeping Analytics"), backgroundColor: Colors.teal),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogDialog,
        label: const Text("New Event"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getCompletedCleaningsStream(widget.hostelType, role: widget.role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No logs found."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              // Logic to calculate average stars
              double avg = 0.0;
              Map ratings = data['ratings'] ?? {};
              if (ratings.isNotEmpty) {
                double total = 0;
                ratings.forEach((k, v) {
                  total += (((v['room'] ?? 0) + (v['bathroom'] ?? 0)) / 2);
                });
                avg = total / ratings.length;
              }

              return Card(
                child: ListTile(
                  title: Text(data['description'] ?? "Cleaning Event"),
                  subtitle: Text("Feedback Count: ${ratings.length}"),
                  trailing: CircleAvatar(
                    backgroundColor: avg < 2.5 ? Colors.red : Colors.green,
                    child: Text(avg.toStringAsFixed(1), style: const TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/housekeeping_service.dart';

class WardenHousekeepingScreen extends StatefulWidget {
  final String hostelType;
  const WardenHousekeepingScreen({super.key, required this.hostelType});

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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Broadcast a housekeeping event to the entire hostel.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: "Description (e.g. Floor 1-3 Deep Clean)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cleaning_services),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
              ElevatedButton(
                onPressed: _isLogging ? null : () async {
                  if (_descController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Description required.")));
                    return;
                  }
                  setDialogState(() => _isLogging = true);
                  try {
                    await _service.startCleaningEvent(
                      hostelType: widget.hostelType,
                      description: _descController.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event Started. Broadcast sent!")));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  } finally {
                    if (context.mounted) setDialogState(() => _isLogging = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: _isLogging 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("START EVENT", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Housekeeping Analytics"),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.maps_home_work, color: Colors.white),
        label: const Text("Start Event", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getCompletedCleaningsStream(widget.hostelType),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No completed cleanings to show.", style: TextStyle(color: Colors.grey)));
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final doc = logs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              double avg = 0.0;
              int ratingCount = 0;
              Map<String, dynamic> ratings = data['ratings'] ?? {};
              
              if (ratings.isNotEmpty) {
                double total = 0;
                ratings.forEach((key, val) {
                  total += (val['average'] as num).toDouble();
                });
                avg = total / ratings.length;
                ratingCount = ratings.length;
              }
              
              bool isWarning = avg > 0 && avg < 2.0;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isWarning ? Colors.red.shade300 : Colors.grey.shade200)
                ),
                margin: const EdgeInsets.only(bottom: 12),
                color: isWarning ? Colors.red.shade50 : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isWarning ? Colors.red.shade100 : Colors.teal.shade100,
                    child: Icon(Icons.star, color: isWarning ? Colors.red : Colors.teal),
                  ),
                  title: Text(
                     data['description'] ?? "Housekeeping Event", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: isWarning ? Colors.red.shade800 : Colors.teal),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['cleaningDate'] != null)
                        Text(
                          "Executed on: ${DateFormat('MMM dd, yyyy').format((data['cleaningDate'] as Timestamp).toDate())}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 4),
                      Text("Total Ratings: $ratingCount", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ratingCount == 0 ? Colors.grey : (isWarning ? Colors.red : Colors.green),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ratingCount == 0 ? "N/A" : "${avg.toStringAsFixed(1)} ★",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
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

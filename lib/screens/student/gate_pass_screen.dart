import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import 'gate_pass_history_screen.dart';

class GatePassScreen extends StatefulWidget {
  final String hostelType;
  final String userName;
  final String roomNo;

  const GatePassScreen({
    super.key,
    required this.hostelType,
    required this.userName,
    required this.roomNo,
  });

  @override
  State<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends State<GatePassScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  // 🚪 1. GENERATE PASS (LEAVING)
  Future<void> _generatePass() async {
    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter destination")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Logic: Save with studentUid so we can filter history later
      await FirebaseFirestore.instance.collection('gate_passes').add({
        'studentUid': user!.uid,
        'studentName': widget.userName,
        'roomNo': widget.roomNo,
        'hostelType': widget.hostelType,
        'destination': _destinationController.text.trim(),
        'status': 'ACTIVE',
        'outTime': FieldValue.serverTimestamp(),
        'inTime': null,
      });

      // Notify Warden via Topic-Based Notification
      await NotificationService.sendGatePassNotification(
        widget.userName,
        _destinationController.text.trim(),
      );

      if (mounted) {
        _destinationController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gate Pass Active! Stay safe."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🏡 2. MARK ENTRY (RETURNING)
  Future<void> _markReturned(String docId) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('gate_passes').doc(docId).update({
        'status': 'CLOSED',
        'inTime': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Welcome Back! Entry logged."),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Not Logged In")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Gate Pass"),
        backgroundColor: Colors.pink.shade400,
        foregroundColor: Colors.white,
        actions: [
          // 📜 History Button for Students to see their own past logs
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GatePassHistoryScreen()),
            ),
            icon: const Icon(Icons.history),
            tooltip: "My History",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Reactive Query: Listens for ONLY the current student's ACTIVE pass
        stream: FirebaseFirestore.instance
            .collection('gate_passes')
            .where('studentUid', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'ACTIVE')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🚨 ACTIVE STATE (Student is currently OUT)
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final doc = snapshot.data!.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            
            // Handle Timestamp conversion safely
            DateTime outTime = (data['outTime'] as Timestamp? ?? Timestamp.now()).toDate();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Card(
                    color: Colors.orange,
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        "STATUS: OUT OF CAMPUS",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.home_work_rounded, size: 100, color: Colors.indigo),
                  const SizedBox(height: 10),
                  Text(
                    "Departure: ${DateFormat('dd MMM, hh:mm a').format(outTime)}",
                    style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 30),
                  
                  // Destination Detail Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text("DESTINATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const SizedBox(height: 5),
                        Text(
                          data['destination'] ?? "N/A",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Return Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _markReturned(doc.id),
                      icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle, size: 28),
                      label: const Text("I HAVE RETURNED (MARK ENTRY)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 📝 GENERATION STATE (Student is in Hostel - No active pass)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Icon(Icons.sensor_door_outlined, size: 100, color: Colors.pink)),
                const SizedBox(height: 20),
                const Text("Gate Pass Generator", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text(
                  "Out-time will be logged automatically using the server timestamp for 100% accuracy.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 30),
                
                // Input Decoration
                TextField(
                  controller: _destinationController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Where are you going?",
                    hintText: "e.g., Local Market, Home, Library",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.location_on_rounded, color: Colors.pink),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Generate Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _generatePass,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade500,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("GENERATE PASS & LEAVE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "By clicking above, your departure is logged in real-time.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // 📅 Used for formatting dates

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  // Function to open the Date Picker
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)), // Max 2 months ahead
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
      });
    }
  }

  void _submitLeave(Map<String, dynamic> userData) async {
  // 1. Validation Check
  if (_startDate == null || _endDate == null || _reasonController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select dates and provide a reason")),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    
    // 2. Data Map (Check these keys match your Firestore)
    final leaveData = {
      'studentUid': user?.uid,
      'studentName': userData['name'] ?? "Unknown",
      'roomNo': userData['roomNo'] ?? "Not Assigned",
      'parentPhone': userData['parentPhone'] ?? "N/A",
      'localGuardianPhone': userData['localGuardianPhone'] ?? "N/A",
      'hostelType': userData['hostelType'] ?? "boys",
      'startDate': Timestamp.fromDate(_startDate!), // 📅 Convert to Firestore Timestamp
      'endDate': Timestamp.fromDate(_endDate!),
      'reason': _reasonController.text.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 3. The Actual Database Call
    await FirebaseFirestore.instance.collection('leave_applications').add(leaveData);

    print("✅ Leave submitted successfully!");

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application Sent to Warden!")),
      );
    }
  } catch (e) {
    // 🔴 THIS WILL TELL YOU EXACTLY WHY IT FAILED
    print("❌ ERROR SUBMITTING LEAVE: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission Failed: $e")),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Request Leave")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📝 Auto-filled Info Header
                _buildAutoFillCard(userData),
                const SizedBox(height: 25),

                const Text("Select Leave Duration", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        label: "From",
                        date: _startDate,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateButton(
                        label: "To",
                        date: _endDate,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 25),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Reason for Leave",
                    border: OutlineInputBorder(),
                    hintText: "e.g., Going home for festival",
                  ),
                ),
                const SizedBox(height: 30),

                _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => _submitLeave(userData),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        child: const Text("SUBMIT TO WARDEN"),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Components ---

  Widget _buildAutoFillCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        children: [
          _rowInfo("Student", data['name']),
          const Divider(),
          _rowInfo("Room No", data['roomNo'] ?? "Not Assigned"),
          const Divider(),
          _rowInfo("Parent Ph", data['parentPhone']),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _dateButton({required String label, DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              date == null ? "Select Date" : DateFormat('dd MMM, yyyy').format(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/parcel_service.dart';

class WardenParcelEntryScreen extends StatefulWidget {
  final String hostelType;
  const WardenParcelEntryScreen({super.key, required this.hostelType});

  @override
  State<WardenParcelEntryScreen> createState() => _WardenParcelEntryScreenState();
}

class _WardenParcelEntryScreenState extends State<WardenParcelEntryScreen> {
  // Removed _isUnknown flag to enforce direct selection
  String? _selectedUid;
  String? _selectedName;
  String? _selectedFcmToken;
  final TextEditingController _descController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = true;
  bool _isUploading = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('hostelType', isEqualTo: widget.hostelType.toLowerCase())
        .get();

    if (mounted) {
      setState(() {
        _students = snapshot.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
        _isLoadingStudents = false;
      });
    }
  }

  void _showAddParcelSheet() {
    // Reset selection for a clean start
    _selectedUid = null;
    _selectedName = null;
    _selectedFcmToken = null;
    _descController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Send Direct Parcel Alert",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Select the specific resident to notify.",
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),

                _isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: "Select Resident Name",
                            prefixIcon: Icon(Icons.person_search),
                            border: OutlineInputBorder()),
                        value: _selectedUid,
                        items: _students.map((student) {
                          return DropdownMenuItem<String>(
                            value: student['uid'],
                            child: Text("${student['name']} (Room: ${student['roomNo'] ?? 'N/A'})"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final selectedStudent = _students.firstWhere((s) => s['uid'] == val);
                          setSheetState(() {
                            _selectedUid = val;
                            _selectedName = selectedStudent['name'];
                            _selectedFcmToken = selectedStudent['fcmToken'];
                          });
                        },
                      ),
                
                const SizedBox(height: 15),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: "Parcel Description (Optional)",
                    hintText: "e.g., Flipkart Box, Home Courier",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 25),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  // Button is disabled until a student is selected
                  onPressed: (_isUploading || _selectedUid == null)
                      ? null
                      : () async {
                          setSheetState(() => _isUploading = true);
                          try {
                            // Enforced ! because button is disabled if _selectedUid is null
                            await ParcelService().addParcel(
                              recipientUid: _selectedUid!,
                              recipientName: _selectedName ?? "Resident",
                              hostelType: widget.hostelType,
                              parcelDescription: _descController.text.trim().isNotEmpty
                                  ? _descController.text.trim()
                                  : null,
                              fcmToken: _selectedFcmToken,
                            );
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Notification sent to student!")));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to send: $e")));
                            }
                          } finally {
                            if (context.mounted) setSheetState(() => _isUploading = false);
                          }
                        },
                  child: _isUploading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SEND DIRECT NOTIFICATION",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Direct Parcel Manager"),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddParcelSheet,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add_alert, color: Colors.white),
        label: const Text("Notify Student", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ParcelService().getWardenParcelsStream(widget.hostelType),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No active parcels.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final parcels = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: parcels.length,
            itemBuilder: (context, index) {
              final doc = parcels[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.local_shipping_outlined, color: Colors.white),
                  ),
                  title: Text(
                    data['recipientName'] ?? "Resident",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status: Awaiting Collection", 
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                      if (data['parcelDescription'] != null)
                        Text("${data['parcelDescription']}", 
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 34),
                    onPressed: () async {
                      bool? confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Confirm Pickup"),
                          content: const Text("Has the resident collected this parcel?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ParcelService().markCollected(doc.id);
                      }
                    },
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
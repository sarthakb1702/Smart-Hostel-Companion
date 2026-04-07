import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/parcel_service.dart';
import 'package:intl/intl.dart';

class WardenParcelManagerScreen extends StatefulWidget {
  final String hostelType;
  const WardenParcelManagerScreen({super.key, required this.hostelType});

  @override
  State<WardenParcelManagerScreen> createState() => _WardenParcelManagerScreenState();
}

class _WardenParcelManagerScreenState extends State<WardenParcelManagerScreen> {
  String? _selectedUid;
  String? _selectedFcmToken;
  final _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('hostelType', isEqualTo: widget.hostelType.toLowerCase())
          .get();

      if (mounted) {
        setState(() {
          _students = snapshot.docs.map((doc) {
            var data = doc.data();
            return {'uid': doc.id, ...data};
          }).toList();
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching students: $e")),
        );
      }
    }
  }

  void _showAddParcelSheet() {
    _selectedUid = null;
    _selectedFcmToken = null;
    _descriptionController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                const Text("Notify Resident of Parcel",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Parcel Description",
                    hintText: "e.g. Amazon Box, Blue Packet",
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                _isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: "Select Resident",
                            border: OutlineInputBorder()),
                        value: _selectedUid,
                        items: _students.map((student) {
                          return DropdownMenuItem<String>(
                            value: student['uid'],
                            child: Text(
                                "${student['name']} (Room: ${student['roomNo'] ?? 'N/A'})"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final selectedStudent =
                              _students.firstWhere((s) => s['uid'] == val);
                          setSheetState(() {
                            _selectedUid = val;
                            _selectedFcmToken = selectedStudent['fcmToken'];
                          });
                        },
                      ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isUploading
                      ? null
                      : () async {
                          if (_descriptionController.text.trim().isEmpty ||
                              _selectedUid == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Please fill all fields")));
                            return;
                          }

                          String recipientNameVal = _students.firstWhere(
                              (s) => s['uid'] == _selectedUid)['name'];

                          setSheetState(() => _isUploading = true);
                          try {
                            await ParcelService().addParcel(
                              recipientUid: _selectedUid!,
                              recipientName: recipientNameVal,
                              parcelDescription:
                                  _descriptionController.text.trim(),
                              hostelType: widget.hostelType,
                              fcmToken: _selectedFcmToken,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Notification sent!")));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e")));
                            }
                          } finally {
                            if (context.mounted) {
                              setSheetState(() => _isUploading = false);
                            }
                          }
                        },
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white))
                      : const Text("SEND ALERT",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("Parcel Management"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: "Active"),
              Tab(icon: Icon(Icons.history), text: "History"),
            ],
            indicatorColor: Colors.indigo,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddParcelSheet,
          backgroundColor: Colors.indigo,
          icon: const Icon(Icons.add_alert, color: Colors.white),
          label: const Text("Add Parcel Alert",
              style: TextStyle(color: Colors.white)),
        ),
        body: TabBarView(
          children: [
            _buildParcelList(status: 'pending'),
            _buildParcelList(status: 'collected'),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelList({required String status}) {
    return StreamBuilder<QuerySnapshot>(
      stream: ParcelService()
          .getWardenParcelsStream(widget.hostelType, status: status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(status == 'pending'
                ? "No active parcels waiting."
                : "No parcel history found."),
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
                leading: CircleAvatar(
                  backgroundColor: status == 'pending' 
                      ? Colors.indigo.shade100 
                      : Colors.green.shade100,
                  child: Icon(
                    status == 'pending' ? Icons.inventory_2 : Icons.history,
                    color: status == 'pending' ? Colors.indigo : Colors.green,
                  ),
                ),
                title: Text(
                  data['recipientName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Note: ${data['parcelDescription'] ?? 'No description'}",
                        style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    if (status == 'collected' && data['collectedAt'] != null)
                      Text(
                        "Collected: ${DateFormat('dd MMM, hh:mm a').format((data['collectedAt'] as Timestamp).toDate())}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
                trailing: status == 'pending'
                    ? IconButton(
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 28),
                        onPressed: () => _confirmCollection(doc.id),
                      )
                    : const Icon(Icons.done_all, color: Colors.green, size: 20),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmCollection(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Collection"),
        content: const Text("Has the student picked up this parcel?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ParcelService().markCollected(docId);
    }
  }
}
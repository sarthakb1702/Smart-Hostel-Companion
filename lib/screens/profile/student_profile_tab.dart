import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class StudentProfileTab extends StatelessWidget {
  const StudentProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("Profile not found."));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String? base64Image = data['profileImageBase64'];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: base64Image != null 
                    ? MemoryImage(base64Decode(base64Image)) 
                    : null,
                child: base64Image == null 
                    ? const Icon(Icons.person, size: 55, color: Colors.indigo) 
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            
            _buildSectionHeader("Hostel & Academic"),
            _profileItem("Name", _safeStr(data['name']), Icons.person_outline),
            _profileItem("Room No", _safeStr(data['roomNo'], defaultStr: "Not Assigned"), Icons.meeting_room_outlined),
            _profileItem("Academic Year", _safeStr(data['year']), Icons.school),
            _profileItem("Hostel Status", _safeStr(data['hostelType'], defaultStr: "N/A").toUpperCase(), Icons.apartment),

            const SizedBox(height: 20),
            
            _buildSectionHeader("Contact Information"),
            _profileItem("Personal Contact", _safeStr(data['phone']), Icons.phone_android),
            _profileItem("Emergency Contact", _safeStr(data['parentPhone']), Icons.family_restroom),
            _profileItem("Local Guardian", _safeStr(data['localGuardianPhone']), Icons.person_search),
            
            const SizedBox(height: 30),
            
            ElevatedButton.icon(
              onPressed: () => _showEditDialog(context, data),
              icon: const Icon(Icons.edit),
              label: const Text("Edit Profile Details"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  String _safeStr(dynamic value, {String defaultStr = "Not Provided"}) {
    if (value == null) return defaultStr;
    String str = value.toString().trim();
    if (str.isEmpty) return defaultStr;
    return str;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 1.1),
      ),
    );
  }

  Widget _profileItem(String label, String value, IconData icon) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final phoneController = TextEditingController(text: data['phone']);
    final parentPhoneController = TextEditingController(text: data['parentPhone']);
    final guardianController = TextEditingController(text: data['localGuardianPhone']);
    final yearController = TextEditingController(text: data['year']);
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.indigo.shade50,
                        backgroundImage: data['profileImageBase64'] != null 
                            ? MemoryImage(base64Decode(data['profileImageBase64'])) 
                            : null,
                        child: data['profileImageBase64'] == null 
                            ? const Icon(Icons.person, size: 40, color: Colors.indigo) : null,
                      ),
                      if (isProcessing)
                        const Positioned.fill(child: CircularProgressIndicator())
                      else
                        InkWell(
                          onTap: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? pickedFile = await picker.pickImage(
                              source: ImageSource.gallery, 
                              maxWidth: 200, 
                              maxHeight: 200, 
                              imageQuality: 30
                            );
                            
                            if (pickedFile == null) return;

                            setDialogState(() => isProcessing = true);
                            try {
                              final bytes = await pickedFile.readAsBytes();
                              String base64String = base64Encode(bytes);

                              final uid = FirebaseAuth.instance.currentUser?.uid;
                              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                'profileImageBase64': base64String,
                              });

                              setDialogState(() => data['profileImageBase64'] = base64String);
                            } catch (e) {
                              debugPrint("Error: $e");
                            } finally {
                              setDialogState(() => isProcessing = false);
                            }
                          },
                          child: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.indigo,
                            child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 10),
                TextField(controller: yearController, decoration: const InputDecoration(labelText: "Academic Year", border: OutlineInputBorder(), prefixIcon: Icon(Icons.school))),
                const SizedBox(height: 10),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Personal Contact", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android))),
                const SizedBox(height: 10),
                TextField(controller: parentPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Emergency Contact", border: OutlineInputBorder(), prefixIcon: Icon(Icons.family_restroom))),
                const SizedBox(height: 10),
                TextField(controller: guardianController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Local Guardian", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_search))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'name': nameController.text.trim(),
                  'year': yearController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'parentPhone': parentPhoneController.text.trim(),
                  'localGuardianPhone': guardianController.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("UPDATE"),
            ),
          ],
        ),
      ),
    );
  }
}
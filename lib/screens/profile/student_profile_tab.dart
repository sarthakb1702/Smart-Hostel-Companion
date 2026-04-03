import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

        // 🚨 Note: Removed Scaffold here because IssueListScreen provides it.
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.indigo,
                backgroundImage: data['profileImageUrl'] != null ? NetworkImage(data['profileImageUrl']) : null,
                child: data['profileImageUrl'] == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
              ),
            ),
            const SizedBox(height: 20),
            
            // Profile Information Groups
            _buildSectionHeader("Hostel Info"),
            _profileItem("Name", data['name'] ?? "N/A", Icons.person_outline),
            _profileItem("Room No", data['roomNo'] ?? "Not Assigned", Icons.meeting_room_outlined),
            
            const SizedBox(height: 10),
            _buildSectionHeader("Emergency Contacts"),
            _profileItem("Personal Phone", data['phone'] ?? "N/A", Icons.phone_android),
            _profileItem("Parent Phone", data['parentPhone'] ?? "N/A", Icons.family_restroom),
            _profileItem("Local Guardian", data['localGuardianPhone'] ?? "None", Icons.person_search),
            _profileItem("Blood Group", data['bloodGroup'] ?? "N/A", Icons.bloodtype, iconColor: Colors.red),
            
            const SizedBox(height: 30),
            
            // Action Buttons
            ElevatedButton.icon(
              onPressed: () => _showEditDialog(context, data),
              icon: const Icon(Icons.edit),
              label: const Text("Edit Profile Details"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // --- UI Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 1.1),
      ),
    );
  }

  Widget _profileItem(String label, String value, IconData icon, {Color iconColor = Colors.indigo}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- Edit Logic ---

  void _showEditDialog(BuildContext context, Map<String, dynamic> data) {
    // 1. Initialize Controllers with existing data
    final nameController = TextEditingController(text: data['name']);
    final phoneController = TextEditingController(text: data['phone']);
    final parentPhoneController = TextEditingController(text: data['parentPhone']);
    final guardianController = TextEditingController(text: data['localGuardianPhone']);
    final deptController = TextEditingController(text: data['department']);
    
    // Dropdown values
    String? tempBloodGroup = data['bloodGroup'];
    String? tempYear = data['year'];

    final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
    final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder for dropdowns in Dialogs
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Profile Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📸 Profile Image Updater Header
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.indigo.shade100,
                        backgroundImage: data['profileImageUrl'] != null ? NetworkImage(data['profileImageUrl']) : null,
                        child: data['profileImageUrl'] == null ? const Icon(Icons.person, size: 40, color: Colors.indigo) : null,
                      ),
                      if (isUploadingImage)
                        const Positioned.fill(
                          child: CircularProgressIndicator(),
                        )
                      else
                        InkWell(
                          onTap: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                            if (image == null) return;

                            setDialogState(() => isUploadingImage = true);
                            try {
                              Reference storageRef = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
                              Uint8List bytes = await image.readAsBytes();
                              TaskSnapshot snapshot = await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
                              String downloadUrl = await snapshot.ref.getDownloadURL();

                              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                'profileImageUrl': downloadUrl,
                              });
                              // update local data map so the UI updates
                              data['profileImageUrl'] = downloadUrl;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile image updated successfully!')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
                              }
                            } finally {
                              setDialogState(() => isUploadingImage = false);
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

                // 🔒 READ ONLY FIELD
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: "Room Number (Contact Warden to change)",
                    hintText: data['roomNo'] ?? "Not Assigned",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 15),
                
                // ✏️ EDITABLE FIELDS
                _buildEditField(nameController, "Full Name", Icons.person),
                _buildEditField(phoneController, "Your Phone", Icons.phone_android),
                _buildEditField(parentPhoneController, "Parent Phone", Icons.family_restroom),
                _buildEditField(guardianController, "Local Guardian", Icons.person_search),
                _buildEditField(deptController, "Department", Icons.school),
                
                const SizedBox(height: 10),
                
                // Blood Group Dropdown
                DropdownButtonFormField<String>(
                  value: tempBloodGroup,
                  decoration: const InputDecoration(labelText: "Blood Group", border: OutlineInputBorder()),
                  items: bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                  onChanged: (val) => setDialogState(() => tempBloodGroup = val),
                ),
                const SizedBox(height: 15),
                
                // Year Dropdown
                DropdownButtonFormField<String>(
                  value: tempYear,
                  decoration: const InputDecoration(labelText: "Year", border: OutlineInputBorder()),
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (val) => setDialogState(() => tempYear = val),
                ),
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
                  'phone': phoneController.text.trim(),
                  'parentPhone': parentPhoneController.text.trim(),
                  'localGuardianPhone': guardianController.text.trim(),
                  'department': deptController.text.trim(),
                  'bloodGroup': tempBloodGroup,
                  'year': tempYear,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("UPDATE PROFILE"),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for dialog text fields
  Widget _buildEditField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
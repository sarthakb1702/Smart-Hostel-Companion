import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _guardianController = TextEditingController();
  final _deptController = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedYear;
  bool _isLoading = false;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-'
  ];
  final List<String> _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

  @override
  void dispose() {
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _guardianController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'phone': _phoneController.text.trim(),
            'parentPhone': _parentPhoneController.text.trim(),
            'localGuardianPhone': _guardianController.text.trim(),
            'bloodGroup': _selectedBloodGroup,
            'department': _deptController.text.trim(),
            'year': _selectedYear,
            'isProfileComplete': true, // 🔓 Unlocks the RoleHandler gate
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving profile: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Your Profile"),
        automaticallyImplyLeading: false,
        actions: [
          // 🚪 Safety Logout button
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚨 Emergency Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                      255, 255, 243, 230), // Soft orange background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color.fromARGB(255, 232, 96, 23), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color.fromARGB(255, 232, 96, 23), size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "SOS & Maintenance features require these details for your safety.",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 1. Student Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Personal Phone Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => (val == null || val.length < 10)
                    ? "Enter valid 10-digit number"
                    : null,
              ),
              const SizedBox(height: 15),

              // 2. Parent Phone
              TextFormField(
                controller: _parentPhoneController,
                decoration: const InputDecoration(
                  labelText: "Parent / Emergency Contact",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom_rounded),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => (val == null || val.length < 10)
                    ? "Required for emergency alerts"
                    : null,
              ),
              const SizedBox(height: 15),

              // 3. Guardian Phone
              TextFormField(
                controller: _guardianController,
                decoration: const InputDecoration(
                  labelText: "Local Guardian Phone (Optional)",
                  hintText: "If any relative lives nearby",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_search_rounded),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),

              // 4. Department
              TextFormField(
                controller: _deptController,
                decoration: const InputDecoration(
                  labelText: "Department (e.g. IT, CSE)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_rounded),
                ),
                validator: (val) => (val == null || val.isEmpty)
                    ? "Please enter your department"
                    : null,
              ),
              const SizedBox(height: 15),

              // 5. Dropdowns (Blood Group & Year)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Blood Group",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      items: _bloodGroups
                          .map((bg) =>
                              DropdownMenuItem(value: bg, child: Text(bg)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedBloodGroup = val),
                      validator: (val) => val == null ? "Select one" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Current Year",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      items: _years
                          .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedYear = val),
                      validator: (val) => val == null ? "Select one" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // 6. Submit Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("COMPLETE REGISTRATION",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

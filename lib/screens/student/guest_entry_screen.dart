import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'guest_history_screen.dart';


class GuestEntryScreen extends StatefulWidget {
    
  const GuestEntryScreen({super.key});

  @override
  State<GuestEntryScreen> createState() => _GuestEntryScreenState();
}

class _GuestEntryScreenState extends State<GuestEntryScreen> {

  // ✅ Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController relationController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String inTime = "";
String outTime = "";
@override
void initState() {
  super.initState();

  final now = TimeOfDay.now();

  inTime =
      "${now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}";
}
Future<void> pickTime(bool isInTime) async {
  TimeOfDay? pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (pickedTime != null) {
    final formattedTime =
        "${pickedTime.hourOfPeriod}:${pickedTime.minute.toString().padLeft(2, '0')} ${pickedTime.period == DayPeriod.am ? 'AM' : 'PM'}";

    setState(() {
      if (isInTime) {
        inTime = formattedTime;
      } else {
        outTime = formattedTime;
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // 🔹 TOP BAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const Text(
                    "Guest Entry",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const GuestHistoryScreen(),
    ),
  );
},
                    ),
                  ),
                ],
              ),


             

              const SizedBox(height: 20),

              // 🔹 VISITOR DETAILS
              sectionTitle("Visitor Details"),

              const SizedBox(height: 10),

              buildField("Guest Full Name", "Enter guest name",
                  icon: Icons.person, controller: nameController),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: buildField("Relationship", "e.g. Father",
                        icon: Icons.group, controller: relationController),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildField("Phone Number", "0123456789",
                        icon: Icons.phone, controller: phoneController),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              buildField("Home Address", "Enter permanent address",
                  icon: Icons.home, controller: addressController),

              const SizedBox(height: 20),

              // 🔹 VISIT LOGISTICS
              sectionTitle("Visit Logistics"),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child:buildTimeField("In-Time", inTime, true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildTimeField("Expected Out-Time", outTime, false),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // 🔵 BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
      relationController.text.isEmpty ||
      phoneController.text.isEmpty ||
      addressController.text.isEmpty ||
      inTime.isEmpty ||
      outTime.isEmpty) {
        
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields")),
    );
    return;
  }
  if (phoneController.text.length != 10) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Phone number must be 10 digits")),
  );
  return;
}
// 📍 GuestEntryScreen.dart → inside onPressed → BEFORE try

String studentName = "";
String roomNo = "";

final user = FirebaseAuth.instance.currentUser;

if (user != null) {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      studentName = userDoc['name'] ?? "";
      roomNo = userDoc['room_no'] ?? "";
    }
  } catch (e) {
    print("User fetch error: $e");
  }
}

DocumentSnapshot userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user!.uid)
    .get();


  try {
    await FirebaseFirestore.instance.collection('guest_entries').add({
      'name': nameController.text,
      'relation': relationController.text,
      'phone': phoneController.text,
      'address': addressController.text,
      'in_time': inTime,
      'out_time': outTime,
      'status': 'pending',   // VERY IMPORTANT (for warden)
      'timestamp': FieldValue.serverTimestamp(),
      'created_by': FirebaseAuth.instance.currentUser?.uid,
       'student_name': studentName,
  'room_no': roomNo,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Guest Entry Submitted")),
    );

    // Clear fields
    nameController.clear();
    relationController.clear();
    phoneController.clear();
    addressController.clear();
    setState(() {
  inTime = "";
  outTime = "";
});

  } catch (e) {
    print("Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Error submitting entry")),
    );
  }
},
                  icon: const Icon(Icons.login),
                  label: const Text(
                    "Register Guest Entry",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "By submitting, you agree that the guest will follow hostel safety protocols.",
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget buildField(String label, String hint,
    {required IconData icon, required TextEditingController controller}) {

  bool isPhoneField = label == "Phone Number"; // 👈 detect phone field

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 5),
      TextField(
        controller: controller,
        keyboardType:
            isPhoneField ? TextInputType.number : TextInputType.text,
        maxLength: isPhoneField ? 10 : null,
        decoration: inputDecoration(hint, icon: icon)
            .copyWith(counterText: ""), // hide counter
      ),
    ],
  );
}

  Widget buildTimeField(String label, String time, bool isInTime) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 5),
      TextField(
        readOnly: true,
        onTap: () => pickTime(isInTime), // 🔥 THIS IS KEY
        decoration: inputDecoration(
          time.isEmpty ? "Select Time" : time,
          icon: Icons.access_time,
        ),
      ),
    ],
  );
}
    
  }

  InputDecoration inputDecoration(String hint,
      {IconData? icon}) {
    return InputDecoration(
      prefixIcon: icon != null ? Icon(icon) : null,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

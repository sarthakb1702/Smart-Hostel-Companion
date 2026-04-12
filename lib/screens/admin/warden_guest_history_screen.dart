import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WardenHistoryScreen extends StatefulWidget {
  const WardenHistoryScreen({super.key});

  @override
  State<WardenHistoryScreen> createState() => _WardenHistoryScreenState();
}

class _WardenHistoryScreenState extends State<WardenHistoryScreen> {

  String selectedFilter = "all"; // 🔥 filter state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History")),

      body: Column(
        children: [

          const SizedBox(height: 10),

          // 🔘 FILTER BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              filterButton("All"),
              filterButton("Approved"),
              filterButton("Rejected"),
            ],
          ),

          const SizedBox(height: 10),

          // 📜 LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedFilter == "all"
                  ? FirebaseFirestore.instance
                      .collection('guest_entries')
                      .where('status', whereIn: ['approved', 'rejected'])
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('guest_entries')
                      .where('status', isEqualTo: selectedFilter)
                      .snapshots(),

              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No records found"));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text("🎓 Student: ${data['student_name'] ?? ''}"),
                            Text("🏠 Room: ${data['room_no'] ?? ''}"),
                            Text("👤 Guest: ${data['name'] ?? ''}"),

                            const SizedBox(height: 5),

                            Text(
                              "Status: ${data['status']}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: data['status'] == 'approved'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 FILTER BUTTON
  Widget filterButton(String text) {
    bool isSelected = selectedFilter == text.toLowerCase();

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey,
      ),
      onPressed: () {
        setState(() {
          selectedFilter = text.toLowerCase();
        });
      },
      child: Text(text),
    );
  }
}
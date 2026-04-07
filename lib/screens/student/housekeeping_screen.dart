import 'package:flutter/material.dart';
import '../../utils/app_colours.dart';
import '../../services/housekeeping_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HousekeepingScreen extends StatefulWidget {
  final String hostelType; // Passed from login/dashboard (e.g., 'boys' or 'girls')
  const HousekeepingScreen({super.key, required this.hostelType});

  @override
  State<HousekeepingScreen> createState() => _HousekeepingScreenState();
}

class _HousekeepingScreenState extends State<HousekeepingScreen> {
  int selectedRating = 5;
  final HousekeepingService _service = HousekeepingService();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          "Housekeeping",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🛡️ CRITICAL FIX: The stream now filters by the student's specific hostelType
        stream: FirebaseFirestore.instance
            .collection('housekeeping_events')
            .where('hostelType', isEqualTo: widget.hostelType.toLowerCase()) // 👈 Added filter
            .where('status', isEqualTo: 'active') // 👈 Only show currently active sessions
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // If no active cleaning session matches the student's building
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoActiveSessionState();
          }

          final eventDoc = snapshot.data!.docs.first;
          final eventData = eventDoc.data() as Map<String, dynamic>;
          final Map ratings = eventData['ratings'] ?? {};
          final bool hasRated = ratings.containsKey(uid);
          
          final String status = eventData['status'] ?? 'inactive';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⭐ HEADER CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Housekeeping Feedback",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(eventData['description'] ?? "Help us improve cleaning quality.",
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // 📝 INPUT SECTION
                if (status == 'active' && !hasRated) ...[
                  const Text("Rate Last Service", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              onPressed: () => setState(() => selectedRating = index + 1),
                              icon: Icon(index < selectedRating ? Icons.star : Icons.star_border,
                                  size: 35, color: Colors.amber),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Anything else we should know?",
                            filled: true,
                            fillColor: AppColors.lightGrey,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 15),
                        GestureDetector(
                          onTap: () async {
                            if (uid != null) {
                              await _service.submitFeedback(
                                eventId: eventDoc.id,
                                uid: uid!,
                                roomRating: selectedRating,
                                bathroomRating: selectedRating,
                                comment: _commentController.text.trim(),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rating submitted!")));
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(12)),
                            child: const Center(child: Text("Submit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        )
                      ],
                    ),
                  ),
                ] else ...[
                  _buildStatusCard(hasRated),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(bool hasRated) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(hasRated ? Icons.check_circle : Icons.info, color: hasRated ? Colors.green : Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasRated 
              ? "You have already submitted feedback for this building. Thank you!" 
              : "This cleaning session is now closed for ratings.",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveSessionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cleaning_services_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No active cleaning session for the ${widget.hostelType.toUpperCase()} hostel.", 
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
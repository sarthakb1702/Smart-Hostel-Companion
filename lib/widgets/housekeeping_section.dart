import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class HousekeepingSection extends StatelessWidget {
  final String hostelType;
  const HousekeepingSection({super.key, required this.hostelType});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      // 📡 Listen for the LATEST cleaning event for the specific hostel
      stream: FirebaseFirestore.instance
          .collection('housekeeping_events')
          .where('hostelType', isEqualTo: hostelType)
          .orderBy('cleaningDate', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildStaticCard("No cleaning records found. ✨");
        }

        final eventDoc = snapshot.data!.docs.first;
        final eventData = eventDoc.data() as Map<String, dynamic>;
        final Map ratings = eventData['ratings'] ?? {};
        final bool hasRated = ratings.containsKey(user?.uid);

        // ✅ SHOW ACTION CARD: If event is active AND student hasn't rated yet
        if (eventData['status'] == 'active' && !hasRated) {
          return _buildActionCard(context, eventDoc.id, eventData['description']);
        }

        // 💤 SHOW STATIC CARD: If no rating is needed right now
        return _buildStaticCard("Everything looks clean! (Last: ${eventData['description'] ?? 'Done'}) ✅");
      },
    );
  }

  // The "Alert" version of the card
  Widget _buildActionCard(BuildContext context, String eventId, String? desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.teal.shade200, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.cleaning_services, color: Colors.teal),
              const SizedBox(width: 10),
              const Expanded(child: Text("Rate Today's Cleaning", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 10))),
            ],
          ),
          const SizedBox(height: 10),
          Text(desc ?? "The warden marked cleaning as complete.", style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () => _showRatingSheet(context, eventId),
              child: const Text("GIVE FEEDBACK"),
            ),
          )
        ],
      ),
    );
  }

  // The "Normal" version of the card
  Widget _buildStaticCard(String message) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        leading: const Icon(Icons.done_all, color: Colors.green),
        title: Text(message, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ),
    );
  }

  // The popup for the rating
  void _showRatingSheet(BuildContext context, String eventId) {
    double roomRating = 5.0;
    double bathRating = 5.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Cleaning Feedback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _ratingRow("Room Cleaning", (v) => roomRating = v),
            const SizedBox(height: 15),
            _ratingRow("Bathroom Cleaning", (v) => bathRating = v),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                await FirebaseFirestore.instance.collection('housekeeping_events').doc(eventId).update({
                  'ratings.$uid': {'room': roomRating, 'bathroom': bathRating, 'timestamp': DateTime.now()}
                });
                Navigator.pop(context);
              },
              child: const Text("SUBMIT RATING"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _ratingRow(String label, Function(double) onUpdate) {
    return Column(children: [
      Text(label),
      RatingBar.builder(
        initialRating: 5, minRating: 1, allowHalfRating: true,
        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
        onRatingUpdate: onUpdate,
      ),
    ]);
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/parcel_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentParcelListWidget extends StatelessWidget {
  final String hostelType;
  const StudentParcelListWidget({super.key, required this.hostelType});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text("My Parcels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: ParcelService().getStudentParcelsStream(uid, hostelType),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text("You have no pending parcels at the desk.", style: TextStyle(color: Colors.grey)),
              );
            }

            final parcels = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true, // IMPORTANT: Allows integration inside Dashboard ListViews
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: parcels.length,
              itemBuilder: (context, index) {
                final data = parcels[index].data() as Map<String, dynamic>;
                final isUnknown = data['recipientUid'] == "UNKNOWN";

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(data['imageUrl'] ?? '', width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: Colors.grey)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUnknown ? "📦 Unknown Parcel Received" : "📦 Your Parcel is Here",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isUnknown ? Colors.orange.shade800 : Colors.indigo,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                isUnknown 
                                  ? "Check the image to see if this belongs to you."
                                  : "Please collect it from the Warden's desk.",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
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
      ],
    );
  }
}

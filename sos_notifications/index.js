const functions = require("firebase-functions");
const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

// Initialize the Admin SDK with your Service Account Key
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

/**
 * This function triggers automatically whenever a new document 
 * is added to the 'sos_alerts' collection in Firestore.
 */
exports.sendSosNotification = functions.firestore
  .document("sos_alerts/{alertId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const studentName = data.studentName;
    const hostel = data.hostelType;

    console.log(`🚀 SOS Triggered by ${studentName} in ${hostel}`);

    try {
      // 1. Find all Wardens assigned to this specific hostel
      const wardensSnapshot = await admin.firestore()
        .collection("users")
        .where("role", "==", "warden")
        .where("hostelType", "==", hostel)
        .get();

      const registrationTokens = [];
      wardensSnapshot.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token) {
          registrationTokens.push(token);
        }
      });

      if (registrationTokens.length === 0) {
        console.log("⚠️ No wardens found with valid FCM tokens.");
        return null;
      }

      // 2. Construct the high-priority message using FCM HTTP v1
      const message = {
        notification: {
          title: `🚨 EMERGENCY SOS: ${studentName}`,
          body: `Hostel: ${hostel} | Immediate help required!`,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel", // Must match your AndroidManifest.xml
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            sound: "default",
          },
        },
        // We use sendEachForMulticast to send to all tokens at once
        tokens: registrationTokens,
      };

      // 3. Send the notification
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`✅ Successfully sent ${response.successCount} notifications.`);
      
      return null;
    } catch (error) {
      console.error("❌ Error sending SOS notification:", error);
      return null;
    }
  });
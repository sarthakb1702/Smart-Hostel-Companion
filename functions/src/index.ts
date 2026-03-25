import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

function generateRandomPassword(length: number = 12) {
  const chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()";
  let password = "";
  for (let i = 0; i < length; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return password;
}

export const createUserWithRole = onCall(async (request) => {
  const { auth, data } = request;

  if (!auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const callerUid = auth.uid;

  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();

  if (!callerDoc.exists) {
    throw new HttpsError("permission-denied", "Caller not found");
  }

  const callerRole = callerDoc.data()?.role;

  if (callerRole !== "head_admin" && callerRole !== "warden") {
    throw new HttpsError("permission-denied", "Not authorized");
  }

  const { name, email, role, hostelType, phone } = data as any;

  if (!name || !email || !role || !hostelType) {
    throw new HttpsError("invalid-argument", "Missing required fields");
  }

  const tempPassword = generateRandomPassword();

  const userRecord = await admin.auth().createUser({
    email,
    password: tempPassword,
    displayName: name,
  });

  await admin.firestore().collection("users").doc(userRecord.uid).set({
    name,
    email,
    role,
    hostelType,
    roomNumber: null,
    phone: phone || "",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const link = await admin.auth().generatePasswordResetLink(email);

  return {
    success: true,
    passwordResetLink: link,
  };
});

class UserModel {
  final String uid;
  final String name;
  final String role;
  final String hostelType;
  final String? fcmToken;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.name,
    required this.role,
    required this.hostelType,
    this.fcmToken,
    this.isActive = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      role: data['role'] ?? 'student',
      hostelType: data['hostelType'] ?? 'general',
      fcmToken: data['fcmToken'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'hostelType': hostelType,
      'fcmToken': fcmToken,
      'isActive': isActive,
    };
  }
}
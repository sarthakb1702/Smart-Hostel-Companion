class InviteModel {
  final String email;
  final String name;
  final String role;
  final String hostelType;
  final String phone;
  final bool isUsed;

  InviteModel({
    required this.email,
    required this.name,
    required this.role,
    required this.hostelType,
    required this.phone,
    required this.isUsed,
  });

  factory InviteModel.fromMap(Map<String, dynamic> data) {
    return InviteModel(
      email: data['email'],
      name: data['name'],
      role: data['role'],
      hostelType: data['hostelType'],
      phone: data['phone'],
      isUsed: data['isUsed'],
    );
  }
}


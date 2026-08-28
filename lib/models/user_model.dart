class UserModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String? email;
  final String? managerId;
  final String? managerName;
  final String? tlId;
  final String? tlName;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.managerId,
    this.managerName,
    this.tlId,
    this.tlName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      email: json['email'],
      managerId: json['manager_id']?.toString(),
      managerName: json['manager_name'],
      tlId: json['tl_id']?.toString(),
      tlName: json['tl_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'email': email,
      'manager_id': managerId,
      'manager_name': managerName,
      'tl_id': tlId,
      'tl_name': tlName,
    };
  }
}

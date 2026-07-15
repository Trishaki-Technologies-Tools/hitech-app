class LeadModel {
  final String id;
  final String customerName;
  final String phone;
  final String? alternatePhone;
  final String requirement;
  String status;
  final String? assignedDse;
  final String? dseName;
  final DateTime createdAt;

  LeadModel({
    required this.id,
    required this.customerName,
    required this.phone,
    this.alternatePhone,
    required this.requirement,
    required this.status,
    this.assignedDse,
    this.dseName,
    required this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id'].toString(),
      customerName: json['customer_name'] ?? '',
      phone: json['phone'] ?? '',
      alternatePhone: json['alternate_phone'],
      requirement: json['requirement'] ?? '',
      status: json['status'] ?? 'New',
      assignedDse: json['assigned_dse']?.toString(),
      dseName: json['dse_name'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'phone': phone,
      'alternate_phone': alternatePhone,
      'requirement': requirement,
      'status': status,
      'assigned_dse': assignedDse,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

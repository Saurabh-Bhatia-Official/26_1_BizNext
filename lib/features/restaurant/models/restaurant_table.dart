import 'dart:convert';

class RestaurantTable {
  final int? id;
  final int businessId;
  final String tableNumber;
  final int capacity;
  final String status; // 'Available', 'Occupied', 'Reserved'
  final String? qrCode;
  final DateTime createdAt;

  RestaurantTable({
    this.id,
    required this.businessId,
    required this.tableNumber,
    required this.capacity,
    required this.status,
    this.qrCode,
    required this.createdAt,
  });

  RestaurantTable copyWith({
    int? id,
    int? businessId,
    String? tableNumber,
    int? capacity,
    String? status,
    String? qrCode,
    DateTime? createdAt,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      tableNumber: tableNumber ?? this.tableNumber,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'table_number': tableNumber,
      'capacity': capacity,
      'status': status,
      'qr_code': qrCode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: map['id']?.toInt(),
      businessId: map['business_id']?.toInt() ?? 1,
      tableNumber: map['table_number'] ?? '',
      capacity: map['capacity']?.toInt() ?? 4,
      status: map['status'] ?? 'Available',
      qrCode: map['qr_code'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  String toJson() => json.encode(toMap());

  factory RestaurantTable.fromJson(String source) => RestaurantTable.fromMap(json.decode(source));
}

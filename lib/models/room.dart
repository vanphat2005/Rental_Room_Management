class Room {
  final int? id;
  final String roomNumber;
  final double rentPrice;
  final double area;
  final String status;
  final String description;
  final int maxOccupants; // Sức chứa tối đa của phòng (mặc định: 2 người)

  const Room({
    this.id,
    required this.roomNumber,
    required this.rentPrice,
    required this.area,
    required this.status,
    required this.description,
    this.maxOccupants = 2,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_number': roomNumber,
      'rent_price': rentPrice,
      'area': area,
      'status': status,
      'description': description,
      'max_occupants': maxOccupants,
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as int?,
      roomNumber: map['room_number'] as String,
      rentPrice: (map['rent_price'] as num).toDouble(),
      area: (map['area'] as num).toDouble(),
      status: map['status'] as String,
      description: map['description'] as String,
      maxOccupants: (map['max_occupants'] as int?) ?? 2,
    );
  }

  Room copyWith({
    int? id,
    String? roomNumber,
    double? rentPrice,
    double? area,
    String? status,
    String? description,
    int? maxOccupants,
  }) {
    return Room(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      rentPrice: rentPrice ?? this.rentPrice,
      area: area ?? this.area,
      status: status ?? this.status,
      description: description ?? this.description,
      maxOccupants: maxOccupants ?? this.maxOccupants,
    );
  }
}

// ============================================================
// Author : Le Van Nguyen - CE181235
// Feature: Invoice Management
// Model  : Invoice Data Model
// ============================================================

/// Thực thể đại diện cho hóa đơn thanh toán tiền phòng và dịch vụ.
class Invoice {
  final int? id;
  final String roomNumber;       // Tên hoặc số phòng (VD: Phòng 101)
  final String monthYear;        // Kỳ thu phí (VD: Tháng 10/2026)
  final double roomPrice;        // Tiền thuê phòng (VNĐ)
  final double electricityCost;  // Tiền điện tiêu thụ (VNĐ)
  final double waterCost;        // Tiền nước sinh hoạt (VNĐ)
  final double otherCost;        // Phí dịch vụ phát sinh khác: rác, wifi... (VNĐ)
  final String status;           // Trạng thái thu: 'unpaid' (chưa thu/chưa trả) hoặc 'paid' (đã thu/đã trả)
  final String note;             // Ghi chú hoặc lời nhắn đính kèm

  const Invoice({
    this.id,
    required this.roomNumber,
    required this.monthYear,
    required this.roomPrice,
    required this.electricityCost,
    required this.waterCost,
    this.otherCost = 0.0,
    required this.status,
    this.note = '',
  });

  /// Tính tổng tiền tự động từ các khoản phí đơn lẻ.
  /// Thiết kế dưới dạng getter tính toán động để loại bỏ nguy cơ lệch số liệu (inconsistent data).
  double get totalAmount => roomPrice + electricityCost + waterCost + otherCost;

  /// Chuyển đối tượng sang Map để ghi dữ liệu vào IndexedDB.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_number': roomNumber,
      'month_year': monthYear,
      'room_price': roomPrice,
      'electricity_cost': electricityCost,
      'water_cost': waterCost,
      'other_cost': otherCost,
      'status': status,
      'note': note,
    };
  }

  /// Khởi tạo đối tượng Invoice từ Map đọc từ IndexedDB.
  /// Ép kiểu số an toàn sang double để tránh lỗi kiểu dữ liệu runtime.
  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      roomNumber: map['room_number'] as String,
      monthYear: map['month_year'] as String,
      roomPrice: (map['room_price'] as num).toDouble(),
      electricityCost: (map['electricity_cost'] as num).toDouble(),
      waterCost: (map['water_cost'] as num).toDouble(),
      otherCost: (map['other_cost'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String,
      note: (map['note'] as String?) ?? '',
    );
  }

  /// Tạo bản sao đối tượng với các thuộc tính được cập nhật (Immutable Pattern).
  Invoice copyWith({
    int? id,
    String? roomNumber,
    String? monthYear,
    double? roomPrice,
    double? electricityCost,
    double? waterCost,
    double? otherCost,
    String? status,
    String? note,
  }) {
    return Invoice(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      monthYear: monthYear ?? this.monthYear,
      roomPrice: roomPrice ?? this.roomPrice,
      electricityCost: electricityCost ?? this.electricityCost,
      waterCost: waterCost ?? this.waterCost,
      otherCost: otherCost ?? this.otherCost,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

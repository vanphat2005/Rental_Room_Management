

class Invoice {
  final int? id;
  final String roomNumber;       // Mã hoặc tên phòng (VD: Phòng 101)
  final String monthYear;        // Tháng/Kỳ hóa đơn (VD: Tháng 10/2026)
  final double roomPrice;        // Tiền thuê phòng (VD: 2.500.000)
  final double electricityCost;  // Tiền điện (VD: 400.000)
  final double waterCost;        // Tiền nước (VD: 150.000)
  final double otherCost;        // Phí dịch vụ khác như rác, wifi (nếu có)
  final String status;           // 'unpaid' (Chưa thanh toán) hoặc 'paid' (Đã thanh toán)
  final String note;             // Ghi chú thêm

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

  // Tính tổng tiền tự động
  double get totalAmount => roomPrice + electricityCost + waterCost + otherCost;

  // Chuyển đối tượng thành Map để lưu vào cơ sở dữ liệu
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

  // Khởi tạo đối tượng từ dữ liệu Map lấy từ cơ sở dữ liệu
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

  // Tạo bản sao mới khi cần thay đổi một số thông tin (như cập nhật trạng thái)
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

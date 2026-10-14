// ============================================================
// File   : lib/models/tenant.dart
// Author : Long
// Mô tả  : Model dữ liệu cho Người thuê phòng (Tenant)
// ============================================================

// BẮT ĐẦU CODE - Long

class Tenant {
  final int? id;

  // Thông tin tài khoản liên kết
  final String username;       // Username tài khoản đăng nhập

  // Thông tin cá nhân
  final String fullName;       // Họ và tên đầy đủ
  final String cccd;           // Số CCCD / CMND

  // Thông tin liên lạc
  final String phone;          // Số điện thoại chính
  final String email;          // Địa chỉ email
  final String address;        // Địa chỉ thường trú

  // Liên hệ khẩn cấp
  final String emergencyContact;      // Tên người liên hệ khẩn cấp
  final String emergencyPhone;        // SĐT người liên hệ khẩn cấp

  // Thông tin thuê phòng
  final String roomNumber;     // Số phòng đang thuê (VD: Phòng 101)
  final String startDate;      // Ngày bắt đầu thuê (VD: 01/10/2026)
  final String endDate;        // Ngày trả phòng (VD: 01/10/2027) - Long thêm

  // Trạng thái
  final String status;         // 'active' (đang thuê) hoặc 'inactive' (đã rời)

  // Ghi chú
  final String note;

  const Tenant({
    this.id,
    required this.username,
    required this.fullName,
    required this.cccd,
    required this.phone,
    this.email = '',
    this.address = '',
    this.emergencyContact = '',
    this.emergencyPhone = '',
    required this.roomNumber,
    required this.startDate,
    this.endDate = '',
    this.status = 'active',
    this.note = '',
  });

  // Chuyển đối tượng thành Map để lưu vào cơ sở dữ liệu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'cccd': cccd,
      'phone': phone,
      'email': email,
      'address': address,
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
      'room_number': roomNumber,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'note': note,
    };
  }

  // Khởi tạo đối tượng từ dữ liệu Map lấy từ cơ sở dữ liệu
  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as int?,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      cccd: map['cccd'] as String,
      phone: map['phone'] as String,
      email: (map['email'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      emergencyContact: (map['emergency_contact'] as String?) ?? '',
      emergencyPhone: (map['emergency_phone'] as String?) ?? '',
      roomNumber: map['room_number'] as String,
      startDate: map['start_date'] as String,
      endDate: (map['end_date'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
      note: (map['note'] as String?) ?? '',
    );
  }

  // Tạo bản sao mới khi cần thay đổi một số thông tin
  Tenant copyWith({
    int? id,
    String? username,
    String? fullName,
    String? cccd,
    String? phone,
    String? email,
    String? address,
    String? emergencyContact,
    String? emergencyPhone,
    String? roomNumber,
    String? startDate,
    String? endDate,
    String? status,
    String? note,
  }) {
    return Tenant(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      cccd: cccd ?? this.cccd,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      roomNumber: roomNumber ?? this.roomNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

// KẾT THÚC CODE - Long

// ============================================================
// File   : lib/models/incident.dart
// Mô tả  : Model dữ liệu cho Sự cố / Bảo trì (Incident)
//          Thêm trạng thái 'closed' và copyWith hoàn chỉnh
// ============================================================

/// Tập hợp tất cả trạng thái hợp lệ của sự cố.
/// Flow hợp lệ: pending → processing → resolved → closed
class IncidentStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String resolved = 'resolved';
  static const String closed = 'closed';

  static const List<String> all = [pending, processing, resolved, closed];

  /// Trả về danh sách trạng thái có thể chuyển tiếp từ [current].
  static List<String> allowedNextStatuses(String current) {
    switch (current) {
      case pending:
        return [pending, processing];
      case processing:
        return [processing, resolved];
      case resolved:
        return [resolved, closed];
      case closed:
        return [closed]; // không thể chuyển ngược
      default:
        return all;
    }
  }

  static String label(String status) {
    switch (status) {
      case pending:    return 'Chưa xử lý';
      case processing: return 'Đang xử lý';
      case resolved:   return 'Đã xử lý';
      case closed:     return 'Đã đóng';
      default:         return status;
    }
  }
}

class Incident {
  final int? id;
  final String roomNumber;       // Số phòng (VD: Phòng 101)
  final String title;            // Tiêu đề sự cố
  final String description;      // Chi tiết mô tả
  final String reportDate;       // Ngày báo cáo (dd/MM/yyyy)
  final String status;           // pending | processing | resolved | closed
  final String resolutionNote;   // Ghi chú xử lý từ chủ trọ
  final bool isArchived;         // Xóa mềm (soft-delete / archive)

  const Incident({
    this.id,
    required this.roomNumber,
    required this.title,
    required this.description,
    required this.reportDate,
    required this.status,
    this.resolutionNote = '',
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_number': roomNumber,
      'title': title,
      'description': description,
      'report_date': reportDate,
      'status': status,
      'resolution_note': resolutionNote,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      id: map['id'] as int?,
      roomNumber: map['room_number'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      reportDate: map['report_date'] as String,
      status: map['status'] as String,
      resolutionNote: (map['resolution_note'] as String?) ?? '',
      isArchived: (map['is_archived'] as int?) == 1,
    );
  }

  Incident copyWith({
    int? id,
    String? roomNumber,
    String? title,
    String? description,
    String? reportDate,
    String? status,
    String? resolutionNote,
    bool? isArchived,
  }) {
    return Incident(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      reportDate: reportDate ?? this.reportDate,
      status: status ?? this.status,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

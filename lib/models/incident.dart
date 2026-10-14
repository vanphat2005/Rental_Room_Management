class Incident {
  final int? id;
  final String roomNumber;       // Mã phòng (VD: P101)
  final String title;            // Tiêu đề sự cố (VD: Hỏng vòi nước, Mất điện...)
  final String description;      // Chi tiết sự cố
  final String reportDate;       // Ngày báo cáo (VD: 14/10/2026)
  final String status;           // 'pending' (Chưa xử lý), 'processing' (Đang xử lý), 'resolved' (Đã xử lý)
  final String resolutionNote;   // Ghi chú / kết quả xử lý của chủ trọ

  const Incident({
    this.id,
    required this.roomNumber,
    required this.title,
    required this.description,
    required this.reportDate,
    required this.status,
    this.resolutionNote = '',
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
  }) {
    return Incident(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      reportDate: reportDate ?? this.reportDate,
      status: status ?? this.status,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }
}

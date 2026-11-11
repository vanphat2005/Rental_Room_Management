// ============================================================
// File   : lib/repositories/incident_repository.dart
// Mô tả  : Repository layer - trung gian giữa Cubit và Database
//          Xử lý business validation: kiểm tra phòng tồn tại,
//          kiểm tra state flow hợp lệ trước khi ghi DB.
// ============================================================

import '../database/incident_database.dart';
import '../database/room_database.dart';
import '../models/incident.dart';

/// Exception có thể bắt và hiển thị message rõ ràng ra UI.
class IncidentException implements Exception {
  final String message;
  const IncidentException(this.message);

  @override
  String toString() => message;
}

class IncidentRepository {
  final IncidentDatabase _incidentDb;
  final RoomDatabase _roomDb;

  IncidentRepository({
    IncidentDatabase? incidentDb,
    RoomDatabase? roomDb,
  })  : _incidentDb = incidentDb ?? IncidentDatabase.instance,
        _roomDb = roomDb ?? RoomDatabase.instance;

  // ─── Validation helpers ────────────────────────────────────

  /// Kiểm tra phòng có tồn tại trong hệ thống không.
  /// Ném [IncidentException] nếu phòng không hợp lệ.
  Future<void> _validateRoomExists(String roomNumber) async {
    if (roomNumber.trim().isEmpty) {
      throw const IncidentException('Vui lòng nhập số phòng.');
    }

    final rooms = await _roomDb.getAllRooms();
    final normalized = roomNumber.trim().toLowerCase();

    final exists = rooms.any((r) =>
      r.roomNumber.trim().toLowerCase() == normalized ||
      'phòng ${r.roomNumber.trim().toLowerCase()}' == normalized ||
      r.roomNumber.trim().toLowerCase() == normalized.replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '').trim(),
    );

    if (!exists) {
      throw IncidentException(
        'Phòng "$roomNumber" không tồn tại trong hệ thống. '
        'Vui lòng kiểm tra lại mã phòng.',
      );
    }
  }

  /// Kiểm tra chuyển đổi trạng thái có hợp lệ theo state flow không.
  void _validateStatusTransition(String currentStatus, String newStatus) {
    if (currentStatus == newStatus) return;

    final allowed = IncidentStatus.allowedNextStatuses(currentStatus);
    if (!allowed.contains(newStatus)) {
      throw IncidentException(
        'Không thể chuyển trạng thái từ '
        '"${IncidentStatus.label(currentStatus)}" '
        'sang "${IncidentStatus.label(newStatus)}". '
        'Flow hợp lệ: Chưa xử lý → Đang xử lý → Đã xử lý → Đã đóng.',
      );
    }
  }

  // ─── Read ───────────────────────────────────────────────────

  Future<List<Incident>> getAll({bool includeArchived = false}) =>
      _incidentDb.getAllIncidents(includeArchived: includeArchived);

  Future<List<Incident>> search(String keyword) =>
      _incidentDb.searchIncidents(keyword);

  // ─── Create ─────────────────────────────────────────────────

  Future<int> create(Incident incident) async {
    await _validateRoomExists(incident.roomNumber);

    if (incident.title.trim().isEmpty) {
      throw const IncidentException('Tiêu đề sự cố không được để trống.');
    }
    if (incident.description.trim().isEmpty) {
      throw const IncidentException('Mô tả chi tiết không được để trống.');
    }

    return _incidentDb.insertIncident(incident);
  }

  // ─── Update status ──────────────────────────────────────────

  Future<void> updateStatus({
    required Incident incident,
    required String newStatus,
    String resolutionNote = '',
  }) async {
    _validateStatusTransition(incident.status, newStatus);

    // Nếu chuyển sang resolved/closed bắt buộc có ghi chú
    if ((newStatus == IncidentStatus.resolved ||
            newStatus == IncidentStatus.closed) &&
        resolutionNote.trim().isEmpty) {
      throw const IncidentException(
        'Vui lòng nhập ghi chú kết quả xử lý trước khi đóng sự cố.',
      );
    }

    final updated = incident.copyWith(
      status: newStatus,
      resolutionNote: resolutionNote.isNotEmpty
          ? resolutionNote
          : incident.resolutionNote,
    );

    final rows = await _incidentDb.updateIncident(updated);
    if (rows == 0) {
      throw const IncidentException('Không tìm thấy sự cố để cập nhật.');
    }
  }

  // ─── Update full (edit) ─────────────────────────────────────

  Future<void> update(Incident incident) async {
    if (incident.id == null) {
      throw const IncidentException('ID sự cố không hợp lệ.');
    }
    await _validateRoomExists(incident.roomNumber);

    final rows = await _incidentDb.updateIncident(incident);
    if (rows == 0) {
      throw const IncidentException('Không tìm thấy sự cố để cập nhật.');
    }
  }

  // ─── Archive / Delete ───────────────────────────────────────

  /// Xóa mềm: sự cố bị ẩn khỏi danh sách nhưng không bị xóa khỏi DB.
  Future<void> archive(int id) async {
    final rows = await _incidentDb.archiveIncident(id);
    if (rows == 0) {
      throw const IncidentException('Không tìm thấy sự cố để lưu trữ.');
    }
  }

  /// Lấy danh sách phòng để hiển thị dropdown.
  Future<List<String>> getAvailableRoomNumbers() async {
    final rooms = await _roomDb.getAllRooms();
    return rooms.map((r) => r.roomNumber).toList()..sort();
  }
}

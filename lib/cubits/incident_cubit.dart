// ============================================================
// File   : lib/cubits/incident_cubit.dart
// Mô tả  : Bloc/Cubit quản lý toàn bộ state cho Incident
//          States: Loading | Loaded | Submitting | Error | Success
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/incident.dart';
import '../repositories/incident_repository.dart';

// ─── State definitions ─────────────────────────────────────

abstract class IncidentState extends Equatable {
  const IncidentState();

  @override
  List<Object?> get props => [];
}

/// Đang tải danh sách lần đầu
class IncidentLoading extends IncidentState {
  const IncidentLoading();
}

/// Danh sách đã load xong, hiển thị bình thường
class IncidentLoaded extends IncidentState {
  final List<Incident> incidents;
  final String filterStatus;   // 'all' | 'pending' | 'processing' | 'resolved' | 'closed'
  final String keyword;
  final List<String> availableRooms;

  const IncidentLoaded({
    required this.incidents,
    this.filterStatus = 'all',
    this.keyword = '',
    this.availableRooms = const [],
  });

  List<Incident> get filtered {
    return incidents.where((i) {
      final matchKeyword = keyword.isEmpty ||
          i.roomNumber.toLowerCase().contains(keyword.toLowerCase()) ||
          i.title.toLowerCase().contains(keyword.toLowerCase()) ||
          i.description.toLowerCase().contains(keyword.toLowerCase());
      final matchStatus =
          filterStatus == 'all' || i.status == filterStatus;
      return matchKeyword && matchStatus;
    }).toList();
  }

  int get pendingCount    => incidents.where((i) => i.status == IncidentStatus.pending).length;
  int get processingCount => incidents.where((i) => i.status == IncidentStatus.processing).length;
  int get resolvedCount   => incidents.where((i) => i.status == IncidentStatus.resolved).length;
  int get closedCount     => incidents.where((i) => i.status == IncidentStatus.closed).length;

  IncidentLoaded copyWith({
    List<Incident>? incidents,
    String? filterStatus,
    String? keyword,
    List<String>? availableRooms,
  }) {
    return IncidentLoaded(
      incidents: incidents ?? this.incidents,
      filterStatus: filterStatus ?? this.filterStatus,
      keyword: keyword ?? this.keyword,
      availableRooms: availableRooms ?? this.availableRooms,
    );
  }

  @override
  List<Object?> get props => [incidents, filterStatus, keyword, availableRooms];
}

/// Đang thực hiện thao tác ghi (create/update/delete)
class IncidentSubmitting extends IncidentState {
  const IncidentSubmitting();
}

/// Thao tác thành công → UI hiển thị snackbar thành công
class IncidentActionSuccess extends IncidentState {
  final String message;
  final List<Incident> incidents;
  final List<String> availableRooms;

  const IncidentActionSuccess({
    required this.message,
    required this.incidents,
    required this.availableRooms,
  });

  @override
  List<Object?> get props => [message, incidents];
}

/// Xảy ra lỗi → UI hiển thị snackbar / dialog lỗi
class IncidentError extends IncidentState {
  final String message;
  /// State trước đó để UI có thể restore
  final IncidentLoaded? previousState;

  const IncidentError({required this.message, this.previousState});

  @override
  List<Object?> get props => [message];
}

// ─── Cubit ──────────────────────────────────────────────────

class IncidentCubit extends Cubit<IncidentState> {
  final IncidentRepository _repo;

  IncidentCubit({IncidentRepository? repo})
      : _repo = repo ?? IncidentRepository(),
        super(const IncidentLoading());

  // ─── Load ─────────────────────────────────────────────────

  Future<void> loadIncidents() async {
    emit(const IncidentLoading());
    try {
      final incidents = await _repo.getAll();
      final rooms = await _repo.getAvailableRoomNumbers();
      emit(IncidentLoaded(incidents: incidents, availableRooms: rooms));
    } catch (e) {
      emit(IncidentError(message: 'Không thể tải dữ liệu: $e'));
    }
  }

  /// Làm mới danh sách (RefreshIndicator kéo xuống) giữ nguyên filter
  Future<void> refresh() async {
    final current = state is IncidentLoaded ? state as IncidentLoaded : null;
    try {
      final incidents = await _repo.getAll();
      final rooms = await _repo.getAvailableRoomNumbers();
      emit(
        current?.copyWith(incidents: incidents, availableRooms: rooms) ??
            IncidentLoaded(incidents: incidents, availableRooms: rooms),
      );
    } catch (e) {
      _emitError('Không thể làm mới danh sách: $e');
    }
  }

  // ─── Filter / Search (không async, chỉ emit state mới) ───

  void filterByStatus(String status) {
    final s = _requireLoaded();
    if (s == null) return;
    emit(s.copyWith(filterStatus: status));
  }

  void search(String keyword) {
    final s = _requireLoaded();
    if (s == null) return;
    emit(s.copyWith(keyword: keyword));
  }

  // ─── Create ───────────────────────────────────────────────

  Future<void> createIncident(Incident incident) async {
    final current = _requireLoaded();
    emit(const IncidentSubmitting());
    try {
      await _repo.create(incident);
      final incidents = await _repo.getAll();
      final rooms = await _repo.getAvailableRoomNumbers();
      emit(IncidentActionSuccess(
        message: 'Đã gửi báo cáo sự cố thành công!',
        incidents: incidents,
        availableRooms: rooms,
      ));
    } on IncidentException catch (e) {
      emit(IncidentError(message: e.message, previousState: current));
    } catch (e) {
      emit(IncidentError(message: 'Lỗi không xác định: $e', previousState: current));
    }
  }

  // ─── Update Status ────────────────────────────────────────

  Future<void> updateStatus({
    required Incident incident,
    required String newStatus,
    String resolutionNote = '',
  }) async {
    final current = _requireLoaded();
    emit(const IncidentSubmitting());
    try {
      await _repo.updateStatus(
        incident: incident,
        newStatus: newStatus,
        resolutionNote: resolutionNote,
      );
      final incidents = await _repo.getAll();
      final rooms = await _repo.getAvailableRoomNumbers();
      emit(IncidentActionSuccess(
        message: 'Cập nhật trạng thái thành công!',
        incidents: incidents,
        availableRooms: rooms,
      ));
    } on IncidentException catch (e) {
      emit(IncidentError(message: e.message, previousState: current));
    } catch (e) {
      emit(IncidentError(message: 'Lỗi cập nhật: $e', previousState: current));
    }
  }

  // ─── Edit full ────────────────────────────────────────────

  Future<void> updateIncident(Incident incident) async {
    final current = _requireLoaded();
    emit(const IncidentSubmitting());
    try {
      await _repo.update(incident);
      final incidents = await _repo.getAll();
      final rooms = await _repo.getAvailableRoomNumbers();
      emit(IncidentActionSuccess(
        message: 'Cập nhật sự cố thành công!',
        incidents: incidents,
        availableRooms: rooms,
      ));
    } on IncidentException catch (e) {
      emit(IncidentError(message: e.message, previousState: current));
    } catch (e) {
      emit(IncidentError(message: 'Lỗi cập nhật: $e', previousState: current));
    }
  }

  // ─── Archive (Soft Delete) ────────────────────────────────

  Future<void> archiveIncident(int id) async {
    final current = _requireLoaded();
    emit(const IncidentSubmitting());
    try {
      await _repo.archive(id);
      final incidents = await _repo.getAll();
      final rooms = await _repo.getAvailableRoomNumbers();
      emit(IncidentActionSuccess(
        message: 'Đã lưu trữ sự cố.',
        incidents: incidents,
        availableRooms: rooms,
      ));
    } on IncidentException catch (e) {
      emit(IncidentError(message: e.message, previousState: current));
    } catch (e) {
      emit(IncidentError(message: 'Lỗi lưu trữ: $e', previousState: current));
    }
  }

  // ─── Helpers ──────────────────────────────────────────────

  IncidentLoaded? _requireLoaded() {
    if (state is IncidentLoaded) return state as IncidentLoaded;
    if (state is IncidentActionSuccess) {
      // sau success UI restore về loaded
      return null;
    }
    return null;
  }

  void _emitError(String msg) {
    final prev = state is IncidentLoaded ? state as IncidentLoaded : null;
    emit(IncidentError(message: msg, previousState: prev));
  }

  /// Sau khi xử lý IncidentActionSuccess / IncidentError, restore về Loaded
  void restoreLoaded(List<Incident> incidents, List<String> rooms) {
    final current = state;
    if (current is IncidentLoaded) return;
    emit(IncidentLoaded(incidents: incidents, availableRooms: rooms));
  }
}

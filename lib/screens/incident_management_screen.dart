// ============================================================
// File   : lib/screens/incident_management_screen.dart
// Mô tả  : Màn hình Quản lý Sự cố - kết nối IncidentCubit
//          Chức năng:
//            - View list + filter + search + RefreshIndicator
//            - Create với validate phòng async
//            - Update status theo state flow
//            - Archive (soft-delete) với AlertDialog xác nhận
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/incident_cubit.dart';
import '../models/incident.dart';

// ─── Entry point: bọc BlocProvider ─────────────────────────

class IncidentManagementScreen extends StatelessWidget {
  const IncidentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => IncidentCubit()..loadIncidents(),
      child: const _IncidentView(),
    );
  }
}

// ─── Main View ───────────────────────────────────────────────

class _IncidentView extends StatelessWidget {
  const _IncidentView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IncidentCubit, IncidentState>(
      // Lắng nghe side effects: thành công / lỗi → hiển thị snackbar
      listener: (context, state) {
        if (state is IncidentActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(state.message)),
              ]),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          // Restore về Loaded sau khi hiển thị success
          context.read<IncidentCubit>().restoreLoaded(
            state.incidents,
            state.availableRooms,
          );
        } else if (state is IncidentError) {
          _showErrorDialog(context, state.message, onRetry: () {
            if (state.previousState != null) {
              context.read<IncidentCubit>().restoreLoaded(
                state.previousState!.incidents,
                state.previousState!.availableRooms,
              );
            } else {
              context.read<IncidentCubit>().loadIncidents();
            }
          });
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Quản lý Sự cố & Bảo trì',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (state is! IncidentLoading)
                IconButton(
                  tooltip: 'Tải lại',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      context.read<IncidentCubit>().loadIncidents(),
                ),
            ],
          ),
          floatingActionButton: state is IncidentLoaded
              ? FloatingActionButton.extended(
                  onPressed: () => _openIncidentForm(context, state),
                  icon: const Icon(Icons.add_alert),
                  label: const Text('Báo cáo sự cố'),
                )
              : null,
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, IncidentState state) {
    if (state is IncidentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is IncidentSubmitting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang xử lý...'),
          ],
        ),
      );
    }

    // IncidentLoaded hoặc IncidentActionSuccess (sẽ nhanh chóng bị replace)
    if (state is IncidentLoaded) {
      return _buildLoadedView(context, state);
    }

    // Error: listener đã show dialog, hiển thị nút retry
    if (state is IncidentError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(state.message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<IncidentCubit>().loadIncidents(),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadedView(BuildContext context, IncidentLoaded state) {
    final cubit = context.read<IncidentCubit>();
    final incidents = state.filtered;

    return Column(
      children: [
        // ── Stat cards ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              _StatCard(label: 'Tổng', count: state.incidents.length,
                  icon: Icons.report_problem, color: Colors.indigo),
              _StatCard(label: 'Chưa xử lý', count: state.pendingCount,
                  icon: Icons.pending_actions, color: Colors.red),
              _StatCard(label: 'Đang xử lý', count: state.processingCount,
                  icon: Icons.sync, color: Colors.orange),
              _StatCard(label: 'Đã xử lý', count: state.resolvedCount,
                  icon: Icons.check_circle, color: Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm theo phòng, tiêu đề sự cố...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            ),
            onChanged: (v) => cubit.search(v),
          ),
        ),
        const SizedBox(height: 8),

        // ── Status filter chips ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Tất cả', value: 'all', selected: state.filterStatus, onTap: cubit.filterByStatus),
                _FilterChip(label: 'Chưa xử lý', value: IncidentStatus.pending, selected: state.filterStatus, onTap: cubit.filterByStatus, color: Colors.red),
                _FilterChip(label: 'Đang xử lý', value: IncidentStatus.processing, selected: state.filterStatus, onTap: cubit.filterByStatus, color: Colors.orange),
                _FilterChip(label: 'Đã xử lý', value: IncidentStatus.resolved, selected: state.filterStatus, onTap: cubit.filterByStatus, color: Colors.green),
                _FilterChip(label: 'Đã đóng', value: IncidentStatus.closed, selected: state.filterStatus, onTap: cubit.filterByStatus, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),

        // ── List ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.refresh(),
            child: incidents.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                state.incidents.isEmpty
                                    ? 'Chưa có sự cố nào được báo cáo'
                                    : 'Không tìm thấy sự cố phù hợp',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    itemCount: incidents.length,
                    itemBuilder: (ctx, i) => _IncidentCard(
                      incident: incidents[i],
                      availableRooms: state.availableRooms,
                      onEdit: () => _openIncidentForm(context, state, incident: incidents[i]),
                      onUpdateStatus: () => _openResolveDialog(context, incidents[i]),
                      onArchive: () => _confirmArchive(context, incidents[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Dialogs / sheets ────────────────────────────────────

  Future<void> _openIncidentForm(
    BuildContext context,
    IncidentLoaded state, {
    Incident? incident,
  }) async {
    final cubit = context.read<IncidentCubit>();
    final result = await showDialog<Incident>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncidentFormDialog(
        incident: incident,
        availableRooms: state.availableRooms,
      ),
    );

    if (result == null) return;

    if (incident == null) {
      await cubit.createIncident(result);
    } else {
      await cubit.updateIncident(result);
    }
  }

  Future<void> _openResolveDialog(
    BuildContext context,
    Incident incident,
  ) async {
    final cubit = context.read<IncidentCubit>();
    final result = await showDialog<_ResolveResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResolveIncidentDialog(incident: incident),
    );

    if (result == null) return;
    await cubit.updateStatus(
      incident: incident,
      newStatus: result.status,
      resolutionNote: result.note,
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    Incident incident,
  ) async {
    final cubit = context.read<IncidentCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.archive_outlined, color: Colors.orange, size: 36),
        title: const Text('Lưu trữ sự cố'),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(ctx).style,
            children: [
              const TextSpan(text: 'Bạn có chắc muốn '),
              TextSpan(
                text: 'lưu trữ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' sự cố\n'),
              TextSpan(
                text: '"${incident.title}"',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const TextSpan(text: ' của '),
              TextSpan(
                text: incident.roomNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '?\n\nSự cố sẽ bị ẩn khỏi danh sách nhưng không bị xóa vĩnh viễn.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Lưu trữ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await cubit.archiveIncident(incident.id!);
  }

  static void _showErrorDialog(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 36),
        title: const Text('Có lỗi xảy ra'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry?.call();
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

// ─── Incident Card Widget ────────────────────────────────────

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final List<String> availableRooms;
  final VoidCallback onEdit;
  final VoidCallback onUpdateStatus;
  final VoidCallback onArchive;

  const _IncidentCard({
    required this.incident,
    required this.availableRooms,
    required this.onEdit,
    required this.onUpdateStatus,
    required this.onArchive,
  });

  Color get _statusColor {
    switch (incident.status) {
      case IncidentStatus.pending:    return Colors.red;
      case IncidentStatus.processing: return Colors.orange;
      case IncidentStatus.resolved:   return Colors.green;
      case IncidentStatus.closed:     return Colors.grey;
      default: return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (incident.status) {
      case IncidentStatus.pending:    return Icons.pending_actions;
      case IncidentStatus.processing: return Icons.sync;
      case IncidentStatus.resolved:   return Icons.check_circle;
      case IncidentStatus.closed:     return Icons.lock_outline;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: phòng + badge trạng thái
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_statusIcon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    incident.roomNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusBadge(status: incident.status),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              incident.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),

            // Description
            Text(
              incident.description,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Báo cáo: ${incident.reportDate}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),

            // Resolution note
            if (incident.resolutionNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Ghi chú xử lý:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(incident.resolutionNote, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],

            const Divider(height: 18),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (incident.status != IncidentStatus.closed)
                  TextButton.icon(
                    onPressed: onUpdateStatus,
                    icon: const Icon(Icons.update, size: 15),
                    label: const Text('Cập nhật', style: TextStyle(fontSize: 13)),
                  ),
                IconButton(
                  tooltip: 'Sửa',
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Lưu trữ',
                  icon: const Icon(Icons.archive_outlined, size: 19, color: Colors.orange),
                  onPressed: onArchive,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get color {
    switch (status) {
      case IncidentStatus.pending:    return Colors.red;
      case IncidentStatus.processing: return Colors.orange;
      case IncidentStatus.resolved:   return Colors.green;
      case IncidentStatus.closed:     return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        IncidentStatus.label(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter Chip ─────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final c = color ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(value),
        selectedColor: c.withValues(alpha: 0.15),
        checkmarkColor: c,
        labelStyle: TextStyle(
          color: isSelected ? c : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? c : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
    );
  }
}

// ─── Create / Edit Form Dialog ───────────────────────────────

class IncidentFormDialog extends StatefulWidget {
  final Incident? incident;
  final List<String> availableRooms;

  const IncidentFormDialog({
    super.key,
    this.incident,
    required this.availableRooms,
  });

  @override
  State<IncidentFormDialog> createState() => _IncidentFormDialogState();
}

class _IncidentFormDialogState extends State<IncidentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _roomController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _dateController;

  late String _status;

  /// Trạng thái validate async phòng
  bool _isCheckingRoom = false;
  String? _roomError;

  @override
  void initState() {
    super.initState();
    final inc = widget.incident;
    _roomController  = TextEditingController(text: inc?.roomNumber ?? '');
    _titleController = TextEditingController(text: inc?.title ?? '');
    _descController  = TextEditingController(text: inc?.description ?? '');
    _dateController  = TextEditingController(
      text: inc?.reportDate ?? _todayFormatted(),
    );
    _status = inc?.status ?? IncidentStatus.pending;
  }

  @override
  void dispose() {
    _roomController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _todayFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Vui lòng nhập thông tin này' : null;

  /// Validate async: kiểm tra phòng có trong danh sách không.
  Future<void> _validateRoom() async {
    final input = _roomController.text.trim();
    if (input.isEmpty) {
      setState(() => _roomError = 'Vui lòng nhập số phòng');
      return;
    }

    setState(() {
      _isCheckingRoom = true;
      _roomError = null;
    });

    await Future.delayed(const Duration(milliseconds: 100)); // debounce nhẹ

    final normalized = input.toLowerCase();
    final exists = widget.availableRooms.any((r) =>
      r.toLowerCase() == normalized ||
      'phòng ${r.toLowerCase()}' == normalized ||
      r.toLowerCase() == normalized.replaceFirst(
        RegExp(r'^phòng\s*', caseSensitive: false), '').trim(),
    );

    if (mounted) {
      setState(() {
        _isCheckingRoom = false;
        _roomError = exists
            ? null
            : 'Phòng "$input" không tồn tại trong hệ thống. '
              'Vui lòng chọn từ danh sách.';
      });
    }
  }

  Future<void> _save() async {
    await _validateRoom();
    if (_roomError != null) return;
    if (!_formKey.currentState!.validate()) return;

    final incident = Incident(
      id: widget.incident?.id,
      roomNumber: _roomController.text.trim(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      reportDate: _dateController.text.trim(),
      status: _status,
      resolutionNote: widget.incident?.resolutionNote ?? '',
    );

    if (mounted) Navigator.pop(context, incident);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.incident != null;

    return AlertDialog(
      title: Text(isEditing ? 'Sửa báo cáo sự cố' : 'Báo cáo sự cố mới'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Room field (autocomplete + async validate) ──
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _roomController.text),
                  optionsBuilder: (v) {
                    if (v.text.isEmpty) return widget.availableRooms;
                    return widget.availableRooms.where(
                      (r) => r.toLowerCase().contains(v.text.toLowerCase()),
                    );
                  },
                  onSelected: (val) {
                    _roomController.text = val;
                    _validateRoom();
                  },
                  fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
                    // Sync controller text từ Autocomplete vào _roomController
                    ctrl.text = _roomController.text;
                    return TextFormField(
                      controller: ctrl,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Số phòng *',
                        hintText: 'Chọn hoặc nhập tên phòng...',
                        border: const OutlineInputBorder(),
                        errorText: _roomError,
                        suffixIcon: _isCheckingRoom
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : (_roomError == null && _roomController.text.isNotEmpty
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null),
                      ),
                      onChanged: (v) {
                        _roomController.text = v;
                        if (v.isNotEmpty) _validateRoom();
                      },
                      onEditingComplete: () {
                        _roomController.text = ctrl.text;
                        _validateRoom();
                        onSubmitted();
                      },
                    );
                  },
                ),

                // Hiển thị danh sách gợi ý nếu chưa có phòng nào
                if (widget.availableRooms.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gợi ý: ${widget.availableRooms.take(4).join(", ")}...',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề sự cố *',
                    hintText: 'VD: Hỏng vòi nước, chập điện...',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết *',
                    hintText: 'Mô tả cụ thể tình trạng hỏng hóc...',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Ngày báo cáo *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(2020),
                          lastDate: now,
                        );
                        if (picked != null && mounted) {
                          _dateController.text =
                              '${picked.day.toString().padLeft(2, '0')}/'
                              '${picked.month.toString().padLeft(2, '0')}/'
                              '${picked.year}';
                        }
                      },
                    ),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái ban đầu',
                    border: OutlineInputBorder(),
                  ),
                  items: IncidentStatus.allowedNextStatuses(_status)
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(IncidentStatus.label(s)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.send, size: 16),
          label: Text(isEditing ? 'Lưu thay đổi' : 'Gửi báo cáo'),
        ),
      ],
    );
  }
}

// ─── Resolve Dialog ──────────────────────────────────────────

class _ResolveResult {
  final String status;
  final String note;
  const _ResolveResult({required this.status, required this.note});
}

class ResolveIncidentDialog extends StatefulWidget {
  final Incident incident;
  const ResolveIncidentDialog({super.key, required this.incident});

  @override
  State<ResolveIncidentDialog> createState() => _ResolveIncidentDialogState();
}

class _ResolveIncidentDialogState extends State<ResolveIncidentDialog> {
  late String _status;
  late final TextEditingController _noteController;
  String? _noteError;

  @override
  void initState() {
    super.initState();
    _status = widget.incident.status;
    _noteController = TextEditingController(text: widget.incident.resolutionNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    // Bắt buộc ghi chú khi resolved/closed
    if ((_status == IncidentStatus.resolved || _status == IncidentStatus.closed) &&
        _noteController.text.trim().isEmpty) {
      setState(() => _noteError = 'Vui lòng nhập ghi chú kết quả xử lý.');
      return;
    }
    Navigator.pop(
      context,
      _ResolveResult(status: _status, note: _noteController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowed = IncidentStatus.allowedNextStatuses(widget.incident.status);
    final needNote = _status == IncidentStatus.resolved ||
        _status == IncidentStatus.closed;

    return AlertDialog(
      title: Text('Cập nhật xử lý — ${widget.incident.roomNumber}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin sự cố
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.incident.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.incident.description,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // State flow indicator
              _StateFlowIndicator(current: widget.incident.status),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái xử lý *',
                  border: OutlineInputBorder(),
                ),
                items: allowed
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              _StatusBadge(status: s),
                              const SizedBox(width: 8),
                              if (s == widget.incident.status)
                                const Text(' (hiện tại)',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _noteController,
                maxLines: 3,
                onChanged: (_) => setState(() => _noteError = null),
                decoration: InputDecoration(
                  labelText: needNote
                      ? 'Ghi chú kết quả xử lý *'
                      : 'Ghi chú xử lý (tùy chọn)',
                  hintText: 'VD: Đã thay mới linh kiện lúc 14h...',
                  border: const OutlineInputBorder(),
                  errorText: _noteError,
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Lưu cập nhật'),
        ),
      ],
    );
  }
}

// ─── State Flow Indicator ─────────────────────────────────────

class _StateFlowIndicator extends StatelessWidget {
  final String current;
  const _StateFlowIndicator({required this.current});

  static const _steps = [
    IncidentStatus.pending,
    IncidentStatus.processing,
    IncidentStatus.resolved,
    IncidentStatus.closed,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps.indexOf(current);

    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIdx = i ~/ 2;
          final passed = stepIdx < currentIdx;
          return Expanded(
            child: Container(
              height: 2,
              color: passed ? Colors.indigo : Colors.grey[300],
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final isDone = stepIdx < currentIdx;
        final isCurrent = stepIdx == currentIdx;
        final step = _steps[stepIdx];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? Colors.indigo
                    : isDone
                        ? Colors.indigo.withValues(alpha: 0.3)
                        : Colors.grey[200],
                border: Border.all(
                  color: isCurrent || isDone ? Colors.indigo : Colors.grey[400]!,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Icon(
                isDone ? Icons.check : Icons.circle,
                size: isDone ? 16 : 8,
                color: isCurrent
                    ? Colors.white
                    : isDone
                        ? Colors.indigo
                        : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              IncidentStatus.label(step),
              style: TextStyle(
                fontSize: 9,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Colors.indigo : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }
}

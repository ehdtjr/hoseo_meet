import 'package:campusmeet/features/auth/presentation/pages/report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../../../widgets/showConfirmDialog.dart';
import '../../../../auth/providers/user_profile_provider.dart';
import '../../../data/models/restaurant/restaurant_post_detail.dart';
import '../../../providers/restaurant/restaurant_post_provider.dart';
import '../../pages/restaurant/location_pick_page.dart';
import 'bottom/edit_history_bottom_sheet.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = '';

    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 7) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length <= 11) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class RestaurantInfoSection extends ConsumerStatefulWidget {
  final RestaurantPostDetail restaurant;
  final void Function(RestaurantPostDetail updated)? onUpdate;

  const RestaurantInfoSection({
    super.key,
    required this.restaurant,
    this.onUpdate,
  });

  @override
  ConsumerState<RestaurantInfoSection> createState() => _RestaurantInfoSectionState();
}

class _RestaurantInfoSectionState extends ConsumerState<RestaurantInfoSection> {
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _latController;
  late TextEditingController _lonController;

  bool _editingAddress = false;
  bool _editingContact = false;
  bool _editingLocation = false;
  bool _editingHours = false;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.restaurant.address);
    _contactController = TextEditingController(text: widget.restaurant.contact ?? '');
    _latController = TextEditingController(text: widget.restaurant.latitude.toString());
    _lonController = TextEditingController(text: widget.restaurant.longitude.toString());

    final parts = (widget.restaurant.businessHours ?? '').split(' - ');
    if (parts.length == 2) {
      _startTime = _parseTime(parts[0]);
      _endTime = _parseTime(parts[1]);
    }
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveUpdate() {
    final hours = (_startTime != null && _endTime != null)
        ? '${_formatTime(_startTime)} - ${_formatTime(_endTime)}'
        : null;

    final updated = widget.restaurant.copyWith(
      address: _addressController.text.trim(),
      contact: _contactController.text.trim(),
      businessHours: hours,
      latitude: double.tryParse(_latController.text.trim()) ?? widget.restaurant.latitude,
      longitude: double.tryParse(_lonController.text.trim()) ?? widget.restaurant.longitude,
    );

    widget.onUpdate?.call(updated);
  }

  void _showEditHistory() async {
    final notifier = ref.read(restaurantPostProvider.notifier);

    // 사용자 ID → 닉네임 매핑 불러오기
    final versions = await notifier.loadRestaurantVersions(widget.restaurant.id, skip: 0, limit: 30);
    final editorIds = versions.map((v) => v.editorId).toSet();

    final userService = ref.read(userServiceProvider);
    final Map<int, String> editorNames = {};

    for (final id in editorIds) {
      try {
        final user = await userService.getUser(id);
        editorNames[id] = user.name;
      } catch (e) {
        editorNames[id] = '사용자 $id';
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditHistoryBottomSheet(
        fetchVersions: ({required int skip, required int limit}) {
          return notifier.loadRestaurantVersions(widget.restaurant.id, skip: skip, limit: limit);
        },
        editorNames: editorNames,
        onTapEditor: (userId) async {
          final userService = ref.read(userServiceProvider);

          try {
            final user = await userService.getUser(userId);
            if (!context.mounted) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportPage(
                  reportedUserId: user.id,
                  reportedUserName: user.name,
                  reportedUserProfile: user.profile,
                ),
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사용자 정보를 불러오지 못했습니다.')),
            );
          }
        },
          onRestore: (version) async {
            await showConfirmDialog(
              context: context,
              title: '이전 버전으로 되돌리기',
              description: '이 버전으로 되돌리시겠습니까?',
              confirmText: '확인',
              onConfirm: () async {
                await notifier.rollbackRestaurantVersion(version.id, widget.restaurant.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이전 버전으로 복원되었습니다.')),
                  );

                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            );
          }

      ),

    );
  }



  Widget _buildEditableRow({
    required String iconPath,
    required Widget content,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    final isEditMode = ref.watch(restaurantEditModeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(iconPath, width: 16, height: 16),
          const SizedBox(width: 6),
          Expanded(child: content),
          isEditing
              ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.check, size: 16), onPressed: onSave),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onCancel),
            ],
          )
              : isEditMode
              ? IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: onEdit)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(restaurantEditModeProvider);
    final editModeNotifier = ref.read(restaurantEditModeProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주소
          _buildEditableRow(
            iconPath: 'assets/icons/fi-rr-marker.svg',
            isEditing: _editingAddress,
            onEdit: () => setState(() => _editingAddress = true),
            onSave: () {
              setState(() => _editingAddress = false);
              _saveUpdate();
            },
            onCancel: () => setState(() => _editingAddress = false),
            content: _editingAddress
                ? TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                hintText: '주소를 입력하세요',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            )
                : Text(
              _addressController.text.isNotEmpty
                  ? _addressController.text
                  : '입력되지 않음',
              style: const TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF5F5F5F)),
            ),
          ),

          // 연락처
          _buildEditableRow(
            iconPath: 'assets/icons/phone.svg',
            isEditing: _editingContact,
            onEdit: () => setState(() => _editingContact = true),
            onSave: () {
              setState(() => _editingContact = false);
              _saveUpdate();
            },
            onCancel: () => setState(() => _editingContact = false),
            content: _editingContact
                ? TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneNumberFormatter()],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                hintText: '연락처를 입력하세요',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            )
                : Text(
              _contactController.text.isNotEmpty
                  ? _contactController.text
                  : '입력되지 않음',
              style: const TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF5F5F5F)),
            ),
          ),

          _buildEditableRow(
            iconPath: 'assets/icons/fi-rr-time-oclock.svg',
            isEditing: _editingHours,
            onEdit: () => setState(() => _editingHours = true),
            onSave: () {
              setState(() => _editingHours = false);
              _saveUpdate();
            },
            onCancel: () => setState(() => _editingHours = false),
            content: _editingHours
                ? Row(
              children: [
                GestureDetector(
                  onTap: () => _selectTime(true),
                  child: Text(
                    _formatTime(_startTime),
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('~', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _selectTime(false),
                  child: Text(
                    _formatTime(_endTime),
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                  ),
                ),
              ],
            )
                : Text(
              (_startTime != null && _endTime != null)
                  ? '${_formatTime(_startTime)} - ${_formatTime(_endTime)}'
                  : '입력되지 않음',
              style: const TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF5F5F5F)),
            ),
          ),


          // 위치
          _buildEditableRow(
            iconPath: 'assets/icons/fi-rr-globe.svg',
            isEditing: _editingLocation,
            onEdit: () => setState(() => _editingLocation = true),
            onSave: () {
              setState(() => _editingLocation = false);
              _saveUpdate();
            },
            onCancel: () => setState(() => _editingLocation = false),
            content: _editingLocation
                ? GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerPage(
                      initialLat: double.tryParse(_latController.text) ?? 37.5665,
                      initialLng: double.tryParse(_lonController.text) ?? 126.9780,
                    ),
                  ),
                );
                if (result != null && result is NLatLng) {
                  setState(() {
                    _latController.text = result.latitude.toStringAsFixed(6);
                    _lonController.text = result.longitude.toStringAsFixed(6);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '지도에서 위치 선택',
                  style: TextStyle(fontSize: 13, color: Colors.blue),
                ),
              ),
            )
                : Text(
              '위도: ${_latController.text}, 경도: ${_lonController.text}',
              style: const TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF5F5F5F)),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  editModeNotifier.state = !isEditMode;
                  setState(() {
                    _editingAddress = false;
                    _editingContact = false;
                    _editingLocation = false;
                    _editingHours = false;
                  });
                },
                icon: Icon(
                  isEditMode ? Icons.close : Icons.edit,
                  size: 13,
                  color: Colors.grey,
                ),
                label: Text(
                  isEditMode ? '편집 취소' : '편집',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              TextButton.icon(
                onPressed: _showEditHistory,
                icon: const Icon(Icons.history, size: 13, color: Colors.grey),
                label: const Text(
                  '수정 이력',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

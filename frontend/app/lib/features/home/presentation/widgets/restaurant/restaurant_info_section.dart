import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../data/models/restaurant/restaurant_post_detail.dart';
import '../../pages/restaurant/location_pick_page.dart';

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

class RestaurantInfoSection extends StatefulWidget {
  final RestaurantPostDetail restaurant;
  final void Function(RestaurantPostDetail updated)? onUpdate;

  const RestaurantInfoSection({
    super.key,
    required this.restaurant,
    this.onUpdate,
  });

  @override
  State<RestaurantInfoSection> createState() => _RestaurantInfoSectionState();
}

class _RestaurantInfoSectionState extends State<RestaurantInfoSection> {
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

  Widget _buildEditableRow({
    required String iconPath,
    required Widget content,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isEditing ? 4 : 1),
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
              : IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: onEdit),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

          // 영업시간
          _buildEditableRow(
            iconPath: 'assets/icons/time.svg',
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
                  child: Text(_formatTime(_startTime)),
                ),
                const SizedBox(width: 4),
                const Text('~'),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _selectTime(false),
                  child: Text(_formatTime(_endTime)),
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

          // 위치 (위도/경도)
          _buildEditableRow(
            iconPath: 'assets/icons/fi-rr-marker.svg',
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
        ],
      ),
    );
  }
}

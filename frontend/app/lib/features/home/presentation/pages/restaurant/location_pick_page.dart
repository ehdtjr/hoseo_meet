import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class LocationPickerPage extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPickerPage({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late NLatLng _selectedPosition;
  late NaverMapController _mapController;

  @override
  void initState() {
    super.initState();
    _selectedPosition = NLatLng(widget.initialLat, widget.initialLng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("위치 선택"),
        backgroundColor: Colors.white, // AppBar 배경색
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _selectedPosition,
                zoom: 16,
              ),
              locationButtonEnable: false,
              indoorEnable: false,
              nightModeEnable: false,
              liteModeEnable: false,
            ),
            onMapReady: (controller) {
              _mapController = controller;
            },
            onCameraIdle: () async {
              final position = await _mapController.getCameraPosition();
              setState(() {
                _selectedPosition = position.target;
              });
            },
          ),

          // 중앙 핀 아이콘
          const Center(
            child: Icon(Icons.location_pin, size: 40, color: Colors.red),
          ),

          // 좌표 텍스트 표시
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "선택된 위치: ${_selectedPosition.latitude.toStringAsFixed(6)}, ${_selectedPosition.longitude.toStringAsFixed(6)}",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),

          // 위치 선택 완료 버튼
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // 배경색을 빨간색으로
                foregroundColor: Colors.white, // 텍스트 색상은 흰색
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, _selectedPosition);
              },
              child: const Text("위치 선택 완료"),
            ),
          ),
        ],
      ),
    );
  }
}

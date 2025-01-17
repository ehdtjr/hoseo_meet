import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

class HomeMap extends StatefulWidget {
  const HomeMap({super.key});

  @override
  _HomeMapState createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  NaverMapController? _mapController;
  late Stream<Position> _positionStream;
  double _currentBearing = 0.0;
  bool _mapReady = false;
  bool _followMode = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _positionStream = getPositionStream();

    // Compass 이벤트 구독
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        setState(() {
          _currentBearing = event.heading!;
        });

        // 서브 아이콘 방향 업데이트 (Follow Mode와 무관)
        _updateSubIcon();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<Position>(
          stream: _positionStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            } else if (snapshot.hasError) {
              return Center(
                  child: Text('위치를 불러오는데 실패했습니다: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              _currentPosition = snapshot.data;
              final position = snapshot.data!;
              final latLng = NLatLng(position.latitude, position.longitude);

              if (_mapController != null && _mapReady) {
                _updateMapLocation(latLng);
              }

              return NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: latLng,
                    zoom: 15,
                    bearing: _currentBearing,
                  ),
                  scrollGesturesEnable: true,
                  zoomGesturesEnable: true,
                  rotationGesturesEnable: true,
                ),
                onMapReady: (controller) async {
                  _mapController = controller;
                  _mapReady = true;

                  final locationOverlay = controller.getLocationOverlay();
                  locationOverlay.setIsVisible(true);
                  locationOverlay.setBearing(_currentBearing);
                  locationOverlay.setPosition(latLng);
                  locationOverlay.setCircleRadius(20);
                  locationOverlay.setSubIcon(
                    const NOverlayImage.fromAssetImage(
                        'packages/flutter_naver_map/assets/icon/location_overlay_sub_icon.png'),
                  );
                  locationOverlay.setSubAnchor(const NPoint(0.5, 1.0));
                },
              );
            } else {
              return const Center(child: Text('위치 정보를 불러오지 못했습니다.'));
            }
          },
        ),

        // Follow Mode 토글 버튼
        Positioned(
          bottom: 80,
          right: 20,
          child: FloatingActionButton(
            onPressed: _toggleFollowMode,
            backgroundColor: _followMode ? Colors.blue : Colors.grey,
            child: Icon(
              _followMode ? Icons.navigation : Icons.navigation_outlined,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Follow Mode 토글
  void _toggleFollowMode() {
    setState(() {
      _followMode = !_followMode;
      if (_followMode) {
        _moveToCurrentLocation(); // Follow Mode 활성화 시 현재 위치로 이동
      }
    });
  }

  // 지도와 서브 아이콘을 현재 위치와 방향으로 업데이트 (Follow Mode와 무관)
  void _updateSubIcon() {
    if (_mapController != null && _currentPosition != null) {
      final latLng = NLatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      // 서브 아이콘 업데이트
      final locationOverlay = _mapController!.getLocationOverlay();
      locationOverlay.setPosition(latLng);
      locationOverlay.setBearing(_currentBearing);
    }
  }

  // 지도 위치 업데이트
  void _updateMapLocation(NLatLng latLng) {
    final locationOverlay = _mapController!.getLocationOverlay();
    locationOverlay.setPosition(latLng);
  }

  // 현재 위치로 카메라 이동
  void _moveToCurrentLocation() {
    if (_mapController != null && _mapReady && _currentPosition != null) {
      final latLng = NLatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      _mapController!.updateCamera(
        NCameraUpdate.withParams(
          target: latLng,
          zoom: 17,
          tilt: 0,
          bearing: _currentBearing,
        ),
      );
    }
  }

  // 위치 스트림 반환
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _mapController = null;
    super.dispose();
  }
}

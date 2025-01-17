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
  Position? _currentPosition;
  double _currentBearing = 0.0; // 나침반 각도
  bool _mapReady = false;
  bool _followAndHeadingMode = false; // 통합 모드 (Follow + Heading)

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCompass();
    _subscribeToPositionUpdates();
  }

  /// 초기 나침반 설정
  void _initializeCompass() {
    FlutterCompass.events?.first.then((event) {
      if (event.heading != null) {
        _currentBearing = event.heading!;
      }
    });

    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        _updateBearing(event.heading!);
      }
    });
  }

  /// 위치 스트림 구독
  void _subscribeToPositionUpdates() {
    _positionSubscription = getPositionStream().listen(
          (position) {
        _updatePosition(position);
      },
      onError: (error) {
        debugPrint('위치 에러: $error');
      },
    );
  }

  /// 위치 업데이트
  void _updatePosition(Position position) {
    setState(() {
      _currentPosition = position;
    });

    if (_followAndHeadingMode) {
      _moveCameraWithHeading();
    } else {
      _updateOverlay(false); // 통합 모드 비활성화 상태에서 아이콘 기본값
    }
  }

  /// 나침반 각도 업데이트
  void _updateBearing(double newBearing) {
    if ((newBearing - _currentBearing).abs() >= 3) {
      _currentBearing = newBearing;

      if (_followAndHeadingMode) {
        _moveCameraWithHeading();
      } else {
        _updateOverlay(false); // 통합 모드 비활성화 상태에서 아이콘 기본값
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Stack(
      children: [
        _buildMap(),
        _buildFloatingButton(),
      ],
    );
  }

  /// 지도 위젯 생성
  Widget _buildMap() {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 15,
          bearing: _currentBearing,
        ),
        rotationGesturesEnable: true,
        scrollGesturesEnable: true,
        zoomGesturesEnable: true,
      ),
      onMapReady: (controller) async {
        _mapController = controller;
        _mapReady = true;
        _updateOverlay(false);
      },
    );
  }

  /// 통합 모드 및 아이콘 상태 토글 버튼 생성
  Widget _buildFloatingButton() {
    return Positioned(
      bottom: 200,
      left: 20,
      child: FloatingActionButton(
        onPressed: _toggleFollowAndHeadingMode,
        backgroundColor: _followAndHeadingMode ? Colors.orange : Colors.grey,
        child: Icon(
          _followAndHeadingMode ? Icons.navigation : Icons.navigation_outlined,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 통합 모드 토글
  void _toggleFollowAndHeadingMode() {
    setState(() {
      _followAndHeadingMode = !_followAndHeadingMode;
    });

    if (_followAndHeadingMode) {
      // 통합 모드 활성화 → 카메라 이동 + 아이콘 업데이트
      _moveCameraWithHeading();
      _updateOverlay(true); // 활성화 상태의 아이콘으로 변경
    } else if (_mapController != null && _currentPosition != null) {
      // 통합 모드 비활성화 → 카메라 고정 + 아이콘 기본값
      _moveCameraToCurrentPosition();
      _updateOverlay(false);
    }
  }

  /// 현재 위치와 나침반 값으로 카메라 이동
  void _moveCameraWithHeading() {
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

      // 서브 아이콘 업데이트
      _updateOverlay(true);
    }
  }

  /// 현재 위치로 카메라 이동 (나침반 값 유지)
  void _moveCameraToCurrentPosition() {
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

  /// 오버레이 업데이트
  void _updateOverlay(bool isFollowMode) {
    if (_mapController != null && _currentPosition != null) {
      final locationOverlay = _mapController!.getLocationOverlay();
      locationOverlay.setIsVisible(true);
      locationOverlay.setPosition(
        NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
      locationOverlay.setBearing(_currentBearing); // 서브 아이콘 각도 반영
      locationOverlay.setSubAnchor(const NPoint(0.5, 1.0));

      if (isFollowMode) {
        // 통합 모드 활성화 상태의 아이콘
        locationOverlay.setSubIcon(
          const NOverlayImage.fromAssetImage(
            'packages/flutter_naver_map/assets/icon/location_overlay_sub_icon_face.png',
          ),
        );
        locationOverlay.setCircleRadius(0); // 반경 제거
      } else {
        // 기본 아이콘
        locationOverlay.setSubIcon(
          const NOverlayImage.fromAssetImage(
            'packages/flutter_naver_map/assets/icon/location_overlay_sub_icon.png',
          ),
        );
        locationOverlay.setCircleRadius(20); // 반경 추가
      }
    }
  }

  /// 위치 스트림
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController = null;
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeMap extends StatefulWidget {
  const HomeMap({super.key});

  @override
  _HomeMapState createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestLocationPermission();
    _initializeCompass();
    _subscribeToPositionUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController = null;
    super.dispose();
  }

  /// 앱 라이프사이클 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[Lifecycle] resumed 상태로 돌아왔습니다.');
      _checkAndRequestLocationPermission();
    }
  }

  /// 위치 권한 확인 및 요청 후, 없으면 사용자에게 묻고 설정으로 이동
  Future<void> _checkAndRequestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;
    print('[Permission] 초기 상태: $status');

    if (status.isDenied || status.isPermanentlyDenied) {
      print('[Permission] 권한이 거부되었거나 영구 거부 상태입니다. 권한 요청을 진행합니다.');
      status = await Permission.location.request();
      print('[Permission] 요청 후 상태: $status');

      if (status.isDenied || status.isPermanentlyDenied) {
        // 바로 이동하지 않고 사용자에게 묻습니다.
        final shouldOpenSettings = await _showPermissionDialog();
        if (shouldOpenSettings == true) {
          print('[Permission] 사용자가 설정으로 이동을 선택했습니다.');
          await openAppSettings();
        } else {
          print('[Permission] 사용자가 설정으로 이동하지 않기로 선택했습니다.');
        }
      }
    } else {
      print('[Permission] 권한이 이미 허용되어 있습니다.');
    }
  }

  /// 권한 설정 화면으로 이동할지 사용자에게 묻는 다이얼로그
  Future<bool?> _showPermissionDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('현재 위치 권한이 거부되어 있습니다. 앱의 기능을 사용하려면 위치 권한이 필요합니다.\n설정에서 권한을 변경하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  /// 초기 나침반 설정
  void _initializeCompass() {
    FlutterCompass.events?.first.then((event) {
      if (event.heading != null) {
        _currentBearing = event.heading!;
      }
    });

    _compassSubscription =
        FlutterCompass.events?.listen((CompassEvent event) {
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
      _updateOverlay(false);
    }
  }

  /// 나침반 각도 업데이트
  void _updateBearing(double newBearing) {
    if ((newBearing - _currentBearing).abs() >= 3) {
      _currentBearing = newBearing;

      if (_followAndHeadingMode) {
        _moveCameraWithHeading();
      } else {
        _updateOverlay(false);
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
      _moveCameraWithHeading();
      _updateOverlay(true);
    } else if (_mapController != null && _currentPosition != null) {
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
        NLatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
      );
      locationOverlay.setBearing(_currentBearing);
      locationOverlay.setSubAnchor(const NPoint(0.5, 1.0));

      if (isFollowMode) {
        locationOverlay.setSubIcon(
          const NOverlayImage.fromAssetImage(
            'packages/flutter_naver_map/assets/icon/location_overlay_sub_icon_face.png',
          ),
        );
        locationOverlay.setCircleRadius(0);
      } else {
        locationOverlay.setSubIcon(
          const NOverlayImage.fromAssetImage(
            'packages/flutter_naver_map/assets/icon/location_overlay_sub_icon.png',
          ),
        );
        locationOverlay.setCircleRadius(20);
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
}

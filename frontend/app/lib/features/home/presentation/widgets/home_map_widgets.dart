import 'package:flutter/cupertino.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart'; // Compass 패키지 추가

class HomeMap extends StatefulWidget {
  const HomeMap({super.key});

  @override
  _HomeMapState createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  NaverMapController? _mapController; // NaverMap 컨트롤러를 저장
  late Stream<Position> _positionStream; // 위치 스트림
  double _currentBearing = 0.0; // Compass로부터 디바이스 방향
  bool _mapReady = false; // 지도 초기화 상태

  @override
  void initState() {
    super.initState();
    _positionStream = getPositionStream(); // 위치 스트림 초기화

    // Flutter Compass 이벤트 구독
    FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        setState(() {
          _currentBearing = event.heading!; // Compass로부터 방향 (0-360도)
        });

        // 나침반 방향이 변경될 때 오버레이의 방향 업데이트
        if (_mapController != null && _mapReady) {
          final locationOverlay = _mapController!.getLocationOverlay();
          locationOverlay.setBearing(_currentBearing); // 방향 업데이트
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Position>(
      stream: _positionStream, // 위치 스트림
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 로딩 상태
          return const Center(child: CupertinoActivityIndicator());
        } else if (snapshot.hasError) {
          // 에러 상태
          return Center(child: Text('위치를 불러오는데 실패했습니다: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          // 위치 데이터가 있을 때
          final position = snapshot.data!;
          final latLng = NLatLng(position.latitude, position.longitude);

          // 지도와 위치 아이콘 업데이트
          if (_mapController != null && _mapReady) {
            final locationOverlay = _mapController!.getLocationOverlay();
            locationOverlay.setPosition(latLng); // 위치 업데이트
          }

          return NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: latLng, // 현재 위치로 초기화
                zoom: 15,
                bearing: _currentBearing, // 초기 Bearing 설정
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
              locationOverlay.setBearing(_currentBearing); // 초기 방향
              locationOverlay.setPosition(latLng); // 초기 위치 설정

              locationOverlay.setCircleRadius(20); // 원 반경
              locationOverlay.setSubIcon(
                const NOverlayImage.fromAssetImage(
                    'packages/flutter_naver_map/assets/icon/location_overlay_sub_icon.png'),
              );
              locationOverlay.setSubAnchor(const NPoint(0.5, 1.0)); // 하단 중앙 기준
            },
          );
        } else {
          return const Center(child: Text('위치 정보를 불러오지 못했습니다.'));
        }
      },
    );
  }

  // 위치 스트림 반환 함수
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // 높은 정확도
      distanceFilter: 1, // 최소 1m 이동 시 업데이트
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}

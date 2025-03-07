import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hoseomeet/features/home/data/models/room_post.dart';
import 'package:hoseomeet/features/home/data/models/room_post_detail.dart';
import '../../data/services/room_post_service.dart';
import 'room_post_category_provider.dart'; // RoomPostCategory 프로바이더

final roomPlaceProvider = Provider<String>((ref) => '');

class RoomPostNotifier extends StateNotifier<List<RoomPost>> {
  final RoomService _service;
  final Ref _ref;

  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 5; // 한 번에 5건씩 로드

  // 현재 위치와 마지막 리로드 위치 저장
  Position? _currentPosition;
  Position? _lastReloadPosition;
  StreamSubscription<Position>? _positionSubscription;

  late final ProviderSubscription<RoomPostCategory> _categorySubscription;

  RoomPostNotifier(this._service, this._ref) : super([]) {
    // roomPostCategoryProvider의 값이 변경되면 데이터를 다시 받아옵니다.
    _categorySubscription = _ref.listen<RoomPostCategory>(
      roomPostCategoryProvider,
          (previous, next) {
        if (previous != next) {
          resetAndLoad();
        }
      },
    );
    // 앱 시작 시 초기 위치를 받아온 후 데이터를 불러오고, 이후 위치 업데이트 구독
    _initializeCurrentPosition().then((_) {
      _lastReloadPosition = _currentPosition;
      loadRoomPosts();
    });
    _subscribeToPositionUpdates();
  }

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  /// 앱 시작 시 초기 위치값을 받아옵니다.
  Future<void> _initializeCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      debugPrint('초기 위치: 위도=${position.latitude}, 경도=${position.longitude}');
    } catch (e) {
      debugPrint('초기 위치 획득 실패: $e');
    }
  }

  /// 위치 스트림을 구독하여 _currentPosition 업데이트 및 10m 이상 이동 시 데이터 재로드
  void _subscribeToPositionUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5m 단위로 업데이트
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (position) {
        _currentPosition = position;
        debugPrint('새 위치 업데이트: 위도=${position.latitude}, 경도=${position.longitude}');
        if (_lastReloadPosition != null) {
          final distanceMoved = Geolocator.distanceBetween(
            _lastReloadPosition!.latitude,
            _lastReloadPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          if (distanceMoved >= 10) {
            _lastReloadPosition = position;
            resetAndLoad();
            debugPrint('10m 이상 이동 감지: 리스트 데이터 재로드');
          }
        } else {
          _lastReloadPosition = position;
        }
      },
      onError: (error) {
        debugPrint('위치 에러: $error');
      },
    );
  }

  /// RoomPost 리스트 로드 (페이지네이션 및 중복 제거 포함)
  Future<void> loadRoomPosts({bool loadMore = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    // API 호출 전에 현재 위치를 최신으로 업데이트합니다.
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      debugPrint('강제 업데이트 위치: 위도=${position.latitude}, 경도=${position.longitude}');
    } catch (e) {
      debugPrint('현재 위치 강제 업데이트 실패: $e');
    }

    final place = _ref.read(roomPlaceProvider);
    final category = _ref.read(roomPostCategoryProvider);

    // RoomPostCategory 열거형을 문자열로 변환합니다.
    String sortBy;
    switch (category) {
      case RoomPostCategory.distance:
        sortBy = 'distance';
        break;
      case RoomPostCategory.rating:
        sortBy = 'rating';
        break;
      case RoomPostCategory.reviews:
        sortBy = 'reviews';
        break;
    }

    double? userLat = _currentPosition?.latitude;
    double? userLon = _currentPosition?.longitude;
    debugPrint('API 호출 전: userLat=$userLat, userLon=$userLon');

    try {
      final posts = await _service.loadListRooms(
        skip: _skip,
        limit: _limit,
        place: place,
        sortBy: sortBy,
        userLat: userLat,
        userLon: userLon,
      );

      if (loadMore) {
        final existingIds = state.map((post) => post.id).toSet();
        final newPosts = posts.where((post) => !existingIds.contains(post.id)).toList();
        state = [...state, ...newPosts];
      } else {
        state = posts;
      }

      // API에서 반환한 리뷰 수가 요청 건수(_limit)보다 적으면 더 이상 불러올 데이터가 없다고 판단
      if (posts.length < _limit) {
        _hasMore = false;
      } else {
        _skip += _limit;
      }
    } catch (e) {
      debugPrint('Failed to load room posts: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 데이터 초기화 후 다시 로드
  void resetAndLoad() {
    _skip = 0;
    _hasMore = true;
    state = [];
    loadRoomPosts();
  }

  /// 특정 roomId에 대한 상세 정보를 조회합니다.
  Future<RoomDetail?> loadRoomDetail(int roomId) async {
    try {
      return await _service.loadRoomDetail(roomId: roomId);
    } catch (e) {
      debugPrint('Failed to load room detail: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _categorySubscription.close();
    super.dispose();
  }
}

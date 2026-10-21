import 'dart:async';
import 'package:campusmeet/features/home/providers/room/room_post_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/room/room_post.dart';
import '../../data/models/room/room_post_detail.dart';
import '../../data/services/room/room_post_service.dart';
import 'room_post_category_provider.dart';

final roomPlaceProvider = Provider<String>((ref) => '');
final roomSearchKeywordProvider = StateProvider<String>((ref) => '');

class RoomPostNotifier extends StateNotifier<List<RoomPost>> {
  final RoomService _service;
  final Ref _ref;

  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 5;

  Position? _currentPosition;
  Position? _lastReloadPosition;
  StreamSubscription<Position>? _positionSubscription;

  late final ProviderSubscription<RoomPostCategory> _categorySubscription;

  RoomPostNotifier(this._service, this._ref) : super([]) {
    _categorySubscription = _ref.listen<RoomPostCategory>(
      roomPostCategoryProvider,
          (previous, next) {
        if (previous != next) {
          Future.microtask(() => resetAndLoad());
        }
      },
    );

    Future.microtask(() => _init());
  }

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> _init() async {
    await _initializeCurrentPosition();
    _lastReloadPosition = _currentPosition;
    await loadRoomPosts();
    _subscribeToPositionUpdates();
  }

  Future<void> _initializeCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      debugPrint('📍 초기 위치: 위도=${position.latitude}, 경도=${position.longitude}');
    } catch (e) {
      debugPrint('⚠️ 초기 위치 획득 실패: $e');
    }
  }

  void _subscribeToPositionUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (position) {
        _currentPosition = position;
        debugPrint('📍 위치 업데이트: 위도=${position.latitude}, 경도=${position.longitude}');

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
            debugPrint('🔁 10m 이상 이동 - 리스트 재로드');
          }
        } else {
          _lastReloadPosition = position;
        }
      },
      onError: (error) {
        debugPrint('⚠️ 위치 스트림 에러: $error');
      },
    );
  }

  Future<void> loadRoomPosts({bool loadMore = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    final place = _ref.read(roomPlaceProvider);
    final category = _ref.read(roomPostCategoryProvider);
    final keyword = _ref.read(roomPostSearchQueryProvider);
    final name = keyword.isEmpty ? null : keyword;

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
      case RoomPostCategory.heart:
        sortBy = 'heart';
        break;
    }

    double? userLat = _currentPosition?.latitude;
    double? userLon = _currentPosition?.longitude;

    debugPrint('📡 API 요청: skip=$_skip, place=$place, sortBy=$sortBy, name=$name');

    try {
      final posts = await _service.loadListRooms(
        skip: _skip,
        limit: _limit,
        place: place,
        sortBy: sortBy,
        userLat: userLat,
        userLon: userLon,
        name: name,
      );

      if (loadMore) {
        final existingIds = state.map((post) => post.id).toSet();
        final newPosts = posts.where((post) => !existingIds.contains(post.id)).toList();
        state = [...state, ...newPosts];
      } else {
        state = posts;
      }

      _hasMore = posts.length >= _limit;
      if (_hasMore) _skip += _limit;
    } catch (e) {
      debugPrint('❌ 방 리스트 불러오기 실패: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> resetAndLoad() async {
    _skip = 0;
    _hasMore = true;
    state = [];
    await loadRoomPosts();
  }

  Future<RoomDetail?> loadRoomDetail(int roomId) async {
    try {
      return await _service.loadRoomDetail(roomId: roomId);
    } catch (e) {
      debugPrint('❌ 방 상세 정보 불러오기 실패: $e');
      return null;
    }
  }

  Future<void> heartRoom(int roomId) async {
    try {
      await _service.heartRoom(roomId: roomId);
      state = [
        for (final post in state)
          if (post.id == roomId) post.copyWith(isHeart: true) else post
      ];
    } catch (e) {
      debugPrint('❌ 하트 등록 실패: $e');
    }
  }

  Future<void> unheartRoom(int roomId) async {
    try {
      await _service.unheartRoom(roomId: roomId);
      state = [
        for (final post in state)
          if (post.id == roomId) post.copyWith(isHeart: false) else post
      ];
    } catch (e) {
      debugPrint('❌ 하트 취소 실패: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _categorySubscription.close();
    super.dispose();
  }
}

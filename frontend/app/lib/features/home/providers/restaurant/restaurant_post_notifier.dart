import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/restaurant/restaurant_post.dart';
import '../../data/models/restaurant/restaurant_post_detail.dart';
import '../../data/models/restaurant/restaurant_version.dart';
import '../../data/services/restaurant/restaurant_post_service.dart';

final restaurantSearchKeywordProvider = StateProvider<String>((ref) => '');

class RestaurantNotifier extends StateNotifier<List<Restaurant>> {
  final RestaurantService _service;
  final Ref _ref;

  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 10;

  Position? _currentPosition;
  Position? _lastReloadPosition;
  StreamSubscription<Position>? _positionSubscription;

  RestaurantNotifier(this._service, this._ref) : super([]) {
    Future.microtask(() => _init());
  }

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> _init() async {
    await _initializeCurrentPosition();
    _lastReloadPosition = _currentPosition;
    await loadRestaurants();
    _subscribeToPositionUpdates();
  }

  Future<void> _initializeCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      debugPrint('📍 현재 위치: 위도=${position.latitude}, 경도=${position.longitude}');
    } catch (e) {
      debugPrint('⚠️ 위치 초기화 실패: $e');
    }
  }

  void _subscribeToPositionUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _currentPosition = position;
      debugPrint('📍 위치 변경 감지: 위도=${position.latitude}, 경도=${position.longitude}');

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
          debugPrint('🔄 위치 10m 이상 이동 - 리스트 재로드');
        }
      } else {
        _lastReloadPosition = position;
      }
    }, onError: (error) {
      debugPrint('⚠️ 위치 스트림 에러: $error');
    });
  }

  Future<void> loadRestaurants({bool loadMore = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    final keyword = _ref.read(restaurantSearchKeywordProvider);
    double? lat = _currentPosition?.latitude;
    double? lon = _currentPosition?.longitude;

    debugPrint('🍽️ 맛집 API 요청: skip=$_skip, keyword=$keyword');

    try {
      final restaurants = await _service.loadRestaurants(
        skip: _skip,
        limit: _limit,
        userLat: lat,
        userLon: lon,
      );

      if (loadMore) {
        final existingIds = state.map((r) => r.id).toSet();
        final newItems = restaurants.where((r) => !existingIds.contains(r.id)).toList();
        state = [...state, ...newItems];
      } else {
        state = restaurants;
      }

      _hasMore = restaurants.length >= _limit;
      if (_hasMore) _skip += _limit;
    } catch (e) {
      debugPrint('❌ 맛집 리스트 로딩 실패: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<RestaurantPostDetail?> loadRestaurantDetail(int restaurantId) async {
    try {
      double? lat = _currentPosition?.latitude;
      double? lon = _currentPosition?.longitude;

      return await _service.loadRestaurantDetail(
        restaurantId: restaurantId,
        userLat: lat,
        userLon: lon,
      );
    } catch (e) {
      debugPrint('❌ 맛집 상세 정보 불러오기 실패: $e');
      return null;
    }
  }

  Future<void> updateRestaurant(RestaurantPostDetail updated) async {
    try {
      await _service.updateRestaurant(updated);

      // 현재 목록에서 해당 맛집 찾아 교체
      final index = state.indexWhere((r) => r.id == updated.id);
      if (index != -1) {
        final updatedRestaurant = Restaurant(
          id: updated.id,
          name: updated.name,
          address: updated.address,
          comment: updated.comment,
          distance: updated.distance.toInt(),
          latitude: updated.latitude,
          longitude: updated.longitude,
          avgRating: updated.avgRating,
          reviewCount: updated.reviewCount,
          isHearted: updated.isHearted,
          images: updated.images,
        );
        state = [
          ...state.sublist(0, index),
          updatedRestaurant,
          ...state.sublist(index + 1),
        ];
      }

      debugPrint('✅ 맛집 정보 업데이트 성공: id=${updated.id}');
    } catch (e) {
      debugPrint('❌ 맛집 정보 업데이트 실패: $e');
      rethrow;
    }
  }

  Future<List<RestaurantVersion>> loadRestaurantVersions(
      int restaurantId, {
        int skip = 0,
        int limit = 10,
      }) async {
    try {
      return await _service.loadRestaurantVersions(
        restaurantId: restaurantId,
        skip: skip,
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ 맛집 버전 목록 조회 실패: $e');
      return [];
    }
  }


  Future<void> resetAndLoad() async {
    _skip = 0;
    _hasMore = true;
    state = [];
    await loadRestaurants();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

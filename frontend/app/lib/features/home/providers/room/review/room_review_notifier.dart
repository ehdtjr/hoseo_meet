import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/data/models/room_review.dart';
import 'package:hoseomeet/features/home/data/services/room_review_service.dart';

class RoomReviewNotifier extends StateNotifier<List<RoomReview>> {
  final RoomReviewService _service;
  final int roomId;

  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 5; // 모든 페이지에서 5건씩 요청

  final String _sortBy = 'latest'; // 최신순 정렬

  // 리뷰 이미지 관련 변수
  List<RoomReviewImage> _images = [];
  bool _isImageLoading = false;
  bool _hasMoreImages = true;
  int _skip = 0;
  final int _limit = 10; // 한번에 가져올 이미지 건수

  RoomReviewNotifier(this._service, this.roomId) : super([]) {
    loadRoomReviews();
    loadRoomReviewImages();
  }

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  List<RoomReviewImage> get images => _images;
  bool get isImageLoading => _isImageLoading;
  bool get hasMoreImages => _hasMoreImages;

  /// 특정 roomId에 대한 리뷰 리스트 로드 (페이지네이션 포함)
  Future<void> loadRoomReviews({bool loadMore = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final reviews = await _service.loadListRoomReviews(
        roomId: roomId,
        page: _page,
        pageSize: _pageSize,
        sortBy: _sortBy,
      );

      if (loadMore) {
        // 중복 제거 후 추가
        final existingIds = state.map((review) => review.id).toSet();
        final newReviews = reviews.where((review) => !existingIds.contains(review.id)).toList();
        state = [...state, ...newReviews];
      } else {
        state = reviews;
      }

      // 반환된 리뷰 수가 요청한 건수보다 적으면 더 이상 불러올 데이터가 없음
      if (reviews.length < _pageSize) {
        _hasMore = false;
      } else {
        _page++;
      }
    } catch (e) {
      debugPrint('Failed to load room reviews: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 리뷰 데이터 초기화 후 다시 로드
  void resetAndLoad() {
    _page = 1;
    _hasMore = true;
    state = [];
    loadRoomReviews();
  }

  /// 특정 roomId에 대한 리뷰 이미지 리스트 로드 (페이지네이션 포함)
  Future<void> loadRoomReviewImages({bool loadMore = false}) async {
    if (_isImageLoading) return;
    _isImageLoading = true;

    try {
      // loadMore가 true인 경우 현재 skip 값을 유지, 아니면 초기화
      if (!loadMore) {
        _skip = 0;
        _hasMoreImages = true;
        _images = [];
      }

      final images = await _service.loadListRoomReviewImages(
        roomId: roomId,
        skip: _skip,
        limit: _limit,
      );

      // 중복 제거 후 추가 (이미지 ID를 기준으로)
      final existingIds = _images.map((image) => image.id).toSet();
      final newImages = images.where((image) => !existingIds.contains(image.id)).toList();
      _images = [..._images, ...newImages];

      // 반환된 이미지 수가 요청한 건수보다 적으면 더 이상 불러올 데이터가 없음
      if (images.length < _limit) {
        _hasMoreImages = false;
      } else {
        _skip += _limit;
      }

      // _images 업데이트 후 state 재할당으로 UI 갱신
      state = [...state];
    } catch (e) {
      debugPrint('Failed to load room review images: $e');
    } finally {
      _isImageLoading = false;
      // 이미지 로딩 완료 후에도 상태 재할당하여 UI 갱신
      state = [...state];
    }
  }

  /// 이미지 데이터 초기화 후 다시 로드
  void resetAndLoadImages() {
    _skip = 0;
    _hasMoreImages = true;
    _images = [];
    loadRoomReviewImages();
  }
}

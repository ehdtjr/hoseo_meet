import 'dart:async';
import 'dart:io';
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
  final int _limit = 10; // 한 번에 가져올 이미지 건수

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
      // 디버그: 요청 전 현재 roomId, page, pageSize, sortBy 출력
      debugPrint('Requesting reviews: roomId=$roomId, page=$_page, pageSize=$_pageSize, sortBy=$_sortBy');

      final reviews = await _service.loadListRoomReviews(
        roomId: roomId,
        page: _page,
        pageSize: _pageSize,
        sortBy: _sortBy,
      );

      // 디버그: API로부터 받은 리뷰 리스트 출력
      debugPrint('Received reviews: ${reviews.length} items');
      for (var review in reviews) {
        debugPrint('Review id: ${review.id}');
      }

      if (loadMore) {
        // 중복 제거 후 추가
        final existingIds = state.map((review) => review.id).toSet();
        final newReviews = reviews.where((review) => !existingIds.contains(review.id)).toList();
        state = [...state, ...newReviews];
        debugPrint('Load more: Added ${newReviews.length} new reviews, total ${state.length}');
      } else {
        state = reviews;
        debugPrint('Initial load: Total ${state.length} reviews loaded');
      }

      // 반환된 리뷰 수가 요청한 건수보다 적으면 더 이상 불러올 데이터가 없음
      if (reviews.length < _pageSize) {
        _hasMore = false;
        debugPrint('No more reviews available');
      } else {
        _page++;
        debugPrint('Incremented page to $_page');
      }
    } catch (e) {
      debugPrint('Failed to load room reviews: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 데이터 초기화 후 다시 로드
  void resetAndLoad() {
    _page = 1;
    _hasMore = true;
    state = [];
    loadRoomReviews();
    loadRoomReviewImages();
  }

  /// 특정 roomId에 대한 리뷰 이미지 리스트 로드 (페이지네이션 포함)
  Future<void> loadRoomReviewImages({bool loadMore = false}) async {
    if (_isImageLoading) return;
    _isImageLoading = true;

    try {
      // loadMore가 false이면 초기화
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

      // 중복 제거 후 추가 (이미지 ID 기준)
      final existingIds = _images.map((image) => image.id).toSet();
      final newImages = images.where((image) => !existingIds.contains(image.id)).toList();
      _images = [..._images, ...newImages];

      // 반환된 이미지 수가 요청한 건수보다 적으면 더 이상 불러올 데이터가 없음
      if (images.length < _limit) {
        _hasMoreImages = false;
      } else {
        _skip += _limit;
      }

      // 상태 업데이트: UI 갱신
      state = [...state];
    } catch (e) {
      debugPrint('Failed to load room review images: $e');
    } finally {
      _isImageLoading = false;
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

  /// 특정 방에 리뷰 작성하기 (create notifier)
  Future<void> createRoomReview({
    required String content,
    required int rating,
    required List<File> images,
  }) async {
    try {
      final newReview = await _service.createRoomReview(
        roomId: roomId,
        content: content,
        rating: rating,
        images: images,
      );
      if (newReview != null) {
        // 새 리뷰를 목록 최상단에 추가 (최신 리뷰 우선)
        state = [newReview, ...state];
      }

      resetAndLoad();
    } catch (e) {
      debugPrint('Error creating room review: $e');
    }
  }

  /// 특정 리뷰 삭제하기 (delete notifier)
  Future<void> deleteRoomReview(int reviewId) async {
    try {
      await _service.deleteRoomReview(reviewId);
      state = state.where((review) => review.id != reviewId).toList();
      debugPrint('Deleted review id: $reviewId');
      resetAndLoad();
    } catch (e) {
      debugPrint('Error deleting room review: $e');
    }
  }

}

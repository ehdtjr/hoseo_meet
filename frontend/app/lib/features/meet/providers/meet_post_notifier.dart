import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/meet/data/models/meet_post.dart';
import 'package:hoseomeet/features/meet/data/models/meet_post_detail.dart';
import '../data/services/meet_poset_service.dart';
import '../providers/meet_post_category_provider.dart';
import 'meet_post_search.dart';

class MeetPostNotifier extends StateNotifier<List<MeetPost>> {
  final MeePostService _service;
  final Ref _ref;

  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 10;

  MeetPostNotifier(this._service, this._ref) : super([]);

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  /// MeetPost 리스트 로드
  Future<void> loadMeetPosts({bool loadMore = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    final category = _ref.read(meetPostCategoryProvider).name;
    final query = _ref.read(searchQueryProvider); // 검색어 가져오기
    final type = category == 'all' ? '' : category;

    try {
      // title 및 content 검색 결과 병합
      final titlePosts = await _service.loadListMeetPost(
        type: type,
        title: query,
        content: '',
        skip: _skip,
        limit: _limit,
      );

      final contentPosts = await _service.loadListMeetPost(
        type: type,
        title: '',
        content: query,
        skip: _skip,
        limit: _limit,
      );

      final combinedPosts = [
        ...titlePosts,
        ...contentPosts,
      ];

      final uniquePosts = {
        for (var post in combinedPosts) post.id: post
      }.values.toList(); // id 기준으로 중복 제거

      if (loadMore) {
        final existingIds = state.map((post) => post.id).toSet();
        final newPosts = uniquePosts.where((post) => !existingIds.contains(post.id)).toList();
        state = [...state, ...newPosts];
      } else {
        state = uniquePosts;
      }

      if (uniquePosts.length < _limit) {
        _hasMore = false;
      } else {
        _skip += _limit;
      }
    } catch (e) {
      debugPrint('Failed to load posts: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 특정 게시글의 상세 정보 로드
  Future<MeetDetail?> loadDetailMeetPost(int postId) async {
    try {
      return await _service.loadDetailMeetPost(postId);
    } catch (e) {
      debugPrint('Failed to load post detail: $e');
      return null;
    }
  }

  /// 게시글 구독
  Future<void> subscribeToPost(int postId) async {
    try {
      await _service.subscribeMeetPost(postId);

      state = state.map((post) {
        if (post.id == postId) {
          return post.copyWith(
            isSubscribed: true,
            currentPeople: post.currentPeople + 1,
          );
        }
        return post;
      }).toList();
    } catch (e) {
      debugPrint('Failed to subscribe to post: $e');
    }
  }

  /// 게시글 생성
  Future<void> createMeetPost({
    required String title,
    required String type,
    required String content,
    required int maxPeople,
  }) async {
    try {
      final createdPost = await _service.createMeetPost(
        title: title,
        type: type,
        content: content,
        maxPeople: maxPeople,
      );

      if (createdPost != null) {
        debugPrint('Created post: $createdPost');
        state = [createdPost, ...state];
      }
    } catch (e) {
      debugPrint('Failed to create meet post: $e');
    }
  }


  /// 데이터 초기화 및 다시 로드
  void resetAndLoad() {
    _skip = 0;
    _hasMore = true;
    state = [];
    loadMeetPosts();
  }
}

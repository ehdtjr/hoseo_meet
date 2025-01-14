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

  /// MeetPost 리스트 로드 (title과 content 각각 검색)
  Future<void> loadMeetPosts({bool loadMore = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    final category = _ref.read(meetPostCategoryProvider).name;
    final query = _ref.read(searchQueryProvider); // 검색어 가져오기
    final type = category == 'all' ? '' : category;

    try {
      // 1. title로 검색
      final titlePosts = await _service.loadListMeetPost(
        type: type,
        title: query,
        content: '',
        skip: _skip,
        limit: _limit,
      );

      // 2. content로 검색
      final contentPosts = await _service.loadListMeetPost(
        type: type,
        title: '',
        content: query,
        skip: _skip,
        limit: _limit,
      );

      // 3. 두 검색 결과 병합 및 중복 제거 (id 기준으로 중복 제거)
      final combinedPosts = [
        ...titlePosts,
        ...contentPosts,
      ];

      final uniquePosts = {
        for (var post in combinedPosts) post.id: post
      }.values.toList(); // id 기준으로 중복 제거

      if (loadMore) {
        state = [...state, ...uniquePosts];
      } else {
        state = uniquePosts;
      }

      // 더 불러올 데이터가 없을 경우 hasMore를 false로 설정
      if (uniquePosts.length < _limit) {
        _hasMore = false;
      } else {
        _skip += _limit;
      }
    } catch (e) {
      print('Failed to load posts: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 특정 게시글의 상세 정보를 로드하는 함수
  Future<MeetDetail?> loadDetailMeetPost(int postId) async {
    try {
      final meetDetail = await _service.loadDetailMeetPost(postId);
      return meetDetail;
    } catch (e) {
      print('Failed to load post detail: $e');
      return null;
    }
  }

  /// 데이터 초기화 및 다시 로드
  void resetAndLoad() {
    _skip = 0;
    _hasMore = true;
    state = []; // 기존 리스트 초기화
    loadMeetPosts(); // 새 데이터 로드
  }
}

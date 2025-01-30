import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/story/data/models/story_post.dart';
import '../data/services/story_post_service.dart';

class StoryPostNotifier extends StateNotifier<List<StoryPost>> {
  final StoryPostService _service;

  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 10;

  StoryPostNotifier(this._service) : super([]) {
    debugPrint("📌 StoryPostNotifier initialized"); // ✅ 생성자 호출 확인
    loadStoryPosts(); // ✅ 최초 실행 확인
  }

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  /// ✅ 스토리 게시물 리스트 로드
  Future<void> loadStoryPosts({bool loadMore = false}) async {
    debugPrint("🟡 loadStoryPosts() called: loadMore=$loadMore, isLoading=$_isLoading, hasMore=$_hasMore");

    if (_isLoading || (!loadMore && state.isNotEmpty)) {
      debugPrint("⏳ Skipping loadStoryPosts() - Already loading or state is not empty");
      return; // ✅ 중복 호출 방지
    }

    _isLoading = true;
    debugPrint("🔵 Fetching story posts...");

    try {
      final posts = await _service.loadListStoryPost();
      debugPrint("✅ Fetched ${posts.length} story posts");

      if (loadMore) {
        final existingIds = state.map((post) => post.id).toSet();
        final newPosts = posts.where((post) => !existingIds.contains(post.id)).toList();
        state = [...state, ...newPosts];
        debugPrint("📌 Added ${newPosts.length} new story posts (Total: ${state.length})");
      } else {
        state = posts;
        debugPrint("📌 Replaced story posts (Total: ${state.length})");
      }

      _hasMore = posts.length >= _limit;
      if (_hasMore) {
        _skip += _limit;
      }
      debugPrint("ℹ️ hasMore=$_hasMore, next skip=$_skip");
    } catch (e) {
      debugPrint("❌ Failed to load story posts: $e");
    } finally {
      _isLoading = false;
      debugPrint("🛑 Loading finished");
    }
  }

  /// ✅ 특정 스토리 게시글 상세 정보 로드
  Future<StoryPost?> loadDetailStoryPost(int postId) async {
    debugPrint("📌 loadDetailStoryPost() called with postId=$postId");
    try {
      final post = await _service.loadDetailStoryPost(postId);
      debugPrint("✅ Successfully loaded detail for postId=$postId");
      return post;
    } catch (e) {
      debugPrint("❌ Failed to load story post detail: $e");
      return null;
    }
  }

  /// ✅ 이미지 업로드 기능 추가
  Future<String?> uploadStoryImage(File imageFile) async {
    debugPrint("📌 uploadStoryImage() called with file: ${imageFile.path}");
    try {
      final uploadedImageUrl = await _service.uploadStoryImage(imageFile);
      debugPrint("✅ Image uploaded successfully: $uploadedImageUrl");
      return uploadedImageUrl;
    } catch (e) {
      debugPrint("❌ Failed to upload image: $e");
      return null;
    }
  }

  /// ✅ 새로운 스토리 게시글 생성
  Future<StoryPost?> createStoryPost(CreateStoryPost post) async {
    debugPrint("📌 createStoryPost() called with imageUrl=${post.imageUrl}");

    try {
      final newPost = await _service.createStoryPost(post);
      debugPrint("✅ Story post created successfully: id=${newPost.id}");

      // 새 게시글을 리스트 최상단에 추가
      state = [newPost, ...state];

      return newPost;
    } catch (e) {
      debugPrint("❌ Failed to create story post: $e");
      return null;
    }
  }

  /// ✅ 스토리 구독하기
  Future<bool> subscribeToStory(int postId) async {
    debugPrint("📌 subscribeToStory() called with postId=$postId");
    try {
      final success = await _service.subscribeToStoryPost(postId);

      if (success) {
        // 성공 시 해당 스토리의 isSubscribed 상태를 true로 업데이트
        state = state.map((post) {
          if (post.id == postId) {
            return post.copyWith(isSubscribed: true);
          }
          return post;
        }).toList();

        debugPrint("✅ Successfully subscribed to story: postId=$postId");
      }

      return success;
    } catch (e) {
      debugPrint("❌ Failed to subscribe to story: $e");
      return false;
    }
  }



  /// ✅ 데이터 초기화 및 다시 로드
  void resetAndLoad() {
    debugPrint("🔄 Reset and reload story posts");
    _skip = 0;
    _hasMore = true;
    state = [];
    loadStoryPosts();
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/models/user.dart';
import '../../auth/data/services/user_service.dart';
import '../data/models/story_post.dart';
import '../data/services/story_post_service.dart';

class StoryPostNotifier extends StateNotifier<List<StoryPost>> {
  final StoryPostService _service;
  final UserService _userService;

  StoryPostNotifier(this._service, this._userService) : super([]) {
    debugPrint("📌 StoryPostNotifier 초기화");
    loadStoryPosts();
  }

  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 10;

  final Map<int, User> _authorCache = {};

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  User? getAuthor(int userId) => _authorCache[userId];

  // ─────────────────────────────────────────────────────────
  // 스토리 리스트 불러오기
  // ─────────────────────────────────────────────────────────
  Future<void> loadStoryPosts({bool loadMore = false}) async {
    debugPrint("🟡 loadStoryPosts() 호출됨: loadMore=$loadMore, isLoading=$_isLoading, hasMore=$_hasMore");

    if (_isLoading || (!loadMore && state.isNotEmpty)) return;

    _isLoading = true;

    try {
      final posts = await _service.loadListStoryPost();
      debugPrint("✅ ${posts.length}개의 스토리 게시물 가져옴");

      if (loadMore) {
        final existingIds = state.map((post) => post.id).toSet();
        final newPosts = posts.where((post) => !existingIds.contains(post.id)).toList();
        state = [...state, ...newPosts];
        await _loadAuthors(newPosts);
      } else {
        state = posts;
        await _loadAuthors(posts);
      }

      _hasMore = posts.length >= _limit;
      if (_hasMore);
    } catch (e) {
      debugPrint("❌ 스토리 게시물 로드 실패: $e");
    } finally {
      _isLoading = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 작성자 정보 불러오기
  // ─────────────────────────────────────────────────────────
  Future<void> _loadAuthors(List<StoryPost> posts) async {
    try {
      final authorIds = posts.map((p) => p.authorId).toSet();
      final idsToFetch = authorIds.where((id) => !_authorCache.containsKey(id)).toList();

      if (idsToFetch.isEmpty) return;

      debugPrint("👤 작성자 ${idsToFetch.length}명 정보 로딩 중...");

      final fetchedUsers = await Future.wait(
        idsToFetch.map((id) => _userService.getUser(id)),
      );

      for (final user in fetchedUsers) {
        _authorCache[user.id] = user;
      }

      debugPrint("✅ 작성자 정보 로딩 완료");
    } catch (e) {
      debugPrint("❌ 작성자 정보 로딩 실패: $e");
    }
  }

  // ─────────────────────────────────────────────────────────
  // 상세 불러오기
  // ─────────────────────────────────────────────────────────
  Future<StoryPost?> loadDetailStoryPost(int postId) async {
    try {
      final post = await _service.loadDetailStoryPost(postId);
      await _loadAuthors([post]);
      return post;
    } catch (e) {
      debugPrint("❌ 상세 로드 실패: $e");
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 이미지 업로드
  // ─────────────────────────────────────────────────────────
  Future<String?> uploadStoryImage(File imageFile) async {
    try {
      File? webpFile = await _convertFileToWebp(imageFile);
      final fileToUpload = webpFile ?? imageFile;
      return await _service.uploadStoryImage(fileToUpload);
    } catch (e) {
      debugPrint("❌ 이미지 업로드 실패: $e");
      return null;
    }
  }

  Future<File?> _convertFileToWebp(File file) async {
    final targetPath = file.path.replaceAll(RegExp(r'\.\w+$'), '.webp');
    try {
      final xFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        format: CompressFormat.webp,
        quality: 100,
      );
      return xFile != null ? File(xFile.path) : null;
    } catch (e) {
      debugPrint("❌ WebP 변환 실패: $e");
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 게시글 생성
  // ─────────────────────────────────────────────────────────
  Future<StoryPost?> createStoryPost(CreateStoryPost post) async {
    try {
      final newPost = await _service.createStoryPost(post);
      state = [newPost, ...state];
      await _loadAuthors([newPost]);
      return newPost;
    } catch (e) {
      debugPrint("❌ 게시글 생성 실패: $e");
      return null;
    }
  }
  Future<void> fetchAuthorsForStories(List<StoryPost> posts) async {
    await _loadAuthors(posts);
  }

  // ─────────────────────────────────────────────────────────
  // 구독 처리
  // ─────────────────────────────────────────────────────────
  Future<bool> subscribeToStory(int postId) async {
    try {
      final success = await _service.subscribeToStoryPost(postId);
      if (success) {
        state = state.map((post) {
          return post.id == postId ? post.copyWith(isSubscribed: true) : post;
        }).toList();
      }
      return success;
    } catch (e) {
      debugPrint("❌ 구독 실패: $e");
      return false;
    }
  }

  Future<bool> deleteStoryPost(int postId) async {
    try {
      final success = await _service.deleteStoryPost(postId);
      if (success) {
        resetAndLoad(); // 삭제 후 전체 목록 새로 로딩
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void resetAndLoad() {
    _hasMore = true;
    state = [];
    loadStoryPosts();
  }
}

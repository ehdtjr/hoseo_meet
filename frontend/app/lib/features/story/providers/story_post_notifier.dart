import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
    debugPrint("📌 StoryPostNotifier 초기화");
    loadStoryPosts();
  }

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  /// 스토리 게시물 리스트 로드
  Future<void> loadStoryPosts({bool loadMore = false}) async {
    debugPrint("🟡 loadStoryPosts() 호출됨: loadMore=$loadMore, isLoading=$_isLoading, hasMore=$_hasMore");

    if (_isLoading || (!loadMore && state.isNotEmpty)) {
      debugPrint("⏳ 중복 호출 방지: 이미 로딩 중이거나 상태가 비어있지 않음");
      return;
    }

    _isLoading = true;
    debugPrint("🔵 스토리 게시물 가져오는 중...");

    try {
      final posts = await _service.loadListStoryPost();
      debugPrint("✅ ${posts.length}개의 스토리 게시물 가져옴");

      if (loadMore) {
        final existingIds = state.map((post) => post.id).toSet();
        final newPosts = posts.where((post) => !existingIds.contains(post.id)).toList();
        state = [...state, ...newPosts];
        debugPrint("📌 ${newPosts.length}개의 새로운 게시물 추가 (총 ${state.length}개)");
      } else {
        state = posts;
        debugPrint("📌 게시물 리스트 갱신 (총 ${state.length}개)");
      }

      _hasMore = posts.length >= _limit;
      if (_hasMore) {
        _skip += _limit;
      }
      debugPrint("ℹ️ hasMore=$_hasMore, 다음 skip=$_skip");
    } catch (e) {
      debugPrint("❌ 스토리 게시물 로드 실패: $e");
    } finally {
      _isLoading = false;
      debugPrint("🛑 로딩 완료");
    }
  }

  /// 특정 스토리 게시글 상세 정보 로드
  Future<StoryPost?> loadDetailStoryPost(int postId) async {
    debugPrint("📌 loadDetailStoryPost() 호출됨: postId=$postId");
    try {
      final post = await _service.loadDetailStoryPost(postId);
      debugPrint("✅ postId=$postId 상세 정보 로드 성공");
      return post;
    } catch (e) {
      debugPrint("❌ 스토리 게시글 상세 정보 로드 실패: $e");
      return null;
    }
  }

  /// 이미지 업로드 (업로드 전에 WebP로 변환)
  Future<String?> uploadStoryImage(File imageFile) async {
    debugPrint("📌 uploadStoryImage() 호출됨: ${imageFile.path}");
    try {
      // 이미지 파일을 WebP로 변환
      File? webpFile = await _convertFileToWebp(imageFile);
      final fileToUpload = webpFile ?? imageFile;
      final uploadedImageUrl = await _service.uploadStoryImage(fileToUpload);
      debugPrint("✅ 이미지 업로드 성공: $uploadedImageUrl");
      return uploadedImageUrl;
    } catch (e) {
      debugPrint("❌ 이미지 업로드 실패: $e");
      return null;
    }
  }

  /// 이미지 파일을 WebP로 변환하는 함수
  Future<File?> _convertFileToWebp(File file) async {
    // 원본 파일의 확장자를 WebP로 변경한 경로 생성
    final targetPath = file.path.replaceAll(RegExp(r'\.\w+$'), '.webp');
    debugPrint("🔄 이미지 변환: ${file.path} -> $targetPath");
    try {
      final xFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        format: CompressFormat.webp,
        quality: 80, // 필요에 따라 품질 수정
      );
      if (xFile != null) {
        final resultFile = File(xFile.path);
        debugPrint("✅ WebP 변환 성공: ${resultFile.path}");
        return resultFile;
      } else {
        debugPrint("⚠️ WebP 변환 실패, 원본 파일 사용");
        return null;
      }
    } catch (e) {
      debugPrint("❌ WebP 변환 중 에러 발생: $e");
      return null;
    }
  }

  /// 새로운 스토리 게시글 생성
  Future<StoryPost?> createStoryPost(CreateStoryPost post) async {
    debugPrint("📌 createStoryPost() 호출됨, imageUrl=${post.imageUrl}");
    try {
      final newPost = await _service.createStoryPost(post);
      debugPrint("✅ 스토리 게시물 생성 성공: id=${newPost.id}");
      // 새 게시물 최상단 추가
      state = [newPost, ...state];
      return newPost;
    } catch (e) {
      debugPrint("❌ 스토리 게시물 생성 실패: $e");
      return null;
    }
  }

  /// 스토리 구독
  Future<bool> subscribeToStory(int postId) async {
    debugPrint("📌 subscribeToStory() 호출됨: postId=$postId");
    try {
      final success = await _service.subscribeToStoryPost(postId);
      if (success) {
        state = state.map((post) {
          if (post.id == postId) {
            return post.copyWith(isSubscribed: true);
          }
          return post;
        }).toList();
        debugPrint("✅ 스토리 구독 성공: postId=$postId");
      }
      return success;
    } catch (e) {
      debugPrint("❌ 스토리 구독 실패: $e");
      return false;
    }
  }

  /// 데이터 초기화 및 다시 로드
  void resetAndLoad() {
    debugPrint("🔄 스토리 게시물 초기화 및 재로딩");
    _skip = 0;
    _hasMore = true;
    state = [];
    loadStoryPosts();
  }
}

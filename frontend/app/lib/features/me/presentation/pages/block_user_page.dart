import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campusmeet/features/auth/data/models/user.dart';
import 'package:campusmeet/features/auth/data/services/user_service.dart';

import '../../../../commons/services/block_manager.dart';
import '../../../auth/providers/user_profile_provider.dart';

class BlockUserPage extends ConsumerStatefulWidget {
  const BlockUserPage({super.key});

  @override
  ConsumerState<BlockUserPage> createState() => _BlockUserPageState();
}

class _BlockUserPageState extends ConsumerState<BlockUserPage> {
  List<User> _blockedUsers = [];
  bool _isLoading = true;

  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = ref.read(userServiceProvider);
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    final ids = await BlockedUsers.getBlockedUserIds();
    final users = <User>[];

    for (final id in ids) {
      try {
        final user = await _userService.getUser(id);
        users.add(user);
      } catch (e) {
        debugPrint('유저 로딩 실패: $e');
      }
    }

    setState(() {
      _blockedUsers = users;
      _isLoading = false;
    });
  }

  Future<void> _unblockUser(User user) async {
    await BlockedUsers.unblockUser(user.id);
    await _loadBlockedUsers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.name} 님을 차단 해제했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('차단한 사용자'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
          ? const Center(child: Text('차단한 사용자가 없습니다.'))
          : ListView.builder(
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
          final profileUrl = user.profile;

          final isValidUrl = profileUrl.trim().isNotEmpty &&
              Uri.tryParse(profileUrl)?.hasAbsolutePath == true;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: SizedBox(
                width: 56,
                height: 56,
                child: ClipOval(
                  child: isValidUrl
                      ? Image.network(
                    profileUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _defaultProfile(),
                  )
                      : _defaultProfile(),
                ),
              ),
              title: Text(user.name),
              trailing: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _unblockUser(user),
              ),
            ),
          );
        },
      ),
    );
  }

  // 기본 프로필 아이콘
  Widget _defaultProfile() {
    return Container(
      color: const Color(0xFFBDBDBD),
      child: const Icon(Icons.person, color: Colors.white, size: 24),
    );
  }
}

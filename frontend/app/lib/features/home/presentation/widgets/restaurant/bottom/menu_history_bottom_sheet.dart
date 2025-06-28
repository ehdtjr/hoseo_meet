import 'package:flutter/material.dart';
import '../../../../data/models/restaurant/restaurant_menmu_version.dart';

class MenuHistoryBottomSheet extends StatefulWidget {
  final Future<List<RestaurantMenuVersion>> Function({
  required int skip,
  required int limit,
  }) fetchVersions;

  final void Function(RestaurantMenuVersion version)? onRestore;

  /// ✅ 이름도 같이 받도록 타입
  final void Function(int userId, String userName)? onTapEditor;

  final Map<int, String> editorNames;

  const MenuHistoryBottomSheet({
    super.key,
    required this.fetchVersions,
    required this.editorNames,
    this.onRestore,
    this.onTapEditor,
  });

  @override
  State<MenuHistoryBottomSheet> createState() =>
      _MenuHistoryBottomSheetState();
}

class _MenuHistoryBottomSheetState extends State<MenuHistoryBottomSheet> {
  final List<RestaurantMenuVersion> _versions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadMoreVersions();
  }

  Future<void> _loadMoreVersions() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final fetched = await widget.fetchVersions(
      skip: _versions.length,
      limit: _limit,
    );
    setState(() {
      _versions.addAll(fetched);
      _isLoading = false;
      if (fetched.length < _limit) _hasMore = false;
    });
  }

  List<Map<String, String>> _extractMenuHistory() {
    final List<Map<String, String>> history = [];

    for (int i = 0; i < _versions.length - 1; i++) {
      final current = _versions[i];
      final previous = _versions[i + 1];

      for (int j = 0; j < current.menus.length; j++) {
        final currentMenu = current.menus[j];
        final previousMenu =
        j < previous.menus.length ? previous.menus[j] : null;

        void compareField(String label, String? oldVal, String? newVal) {
          if ((oldVal ?? '').trim() != (newVal ?? '').trim()) {
            history.add({
              'date': current.createdAt.toString(),
              'editorId': current.editorId.toString(),
              'editor': widget.editorNames[current.editorId] ??
                  '사용자 ${current.editorId}',
              'field': label,
              'old': oldVal ?? '',
              'new': newVal ?? '',
              'version': current.version.toString(),
              'menuName': currentMenu.name,
              'type': label == '이미지' ? 'image' : 'text',
            });
          }
        }

        if (previousMenu != null) {
          compareField('이름', previousMenu.name, currentMenu.name);
          compareField('가격', previousMenu.price.toString(),
              currentMenu.price.toString());
          compareField('이미지', previousMenu.image, currentMenu.image);
        } else {
          history.add({
            'date': current.createdAt.toString(),
            'editorId': current.editorId.toString(),
            'editor': widget.editorNames[current.editorId] ??
                '사용자 ${current.editorId}',
            'field': '메뉴 추가됨',
            'old': '',
            'new': currentMenu.name,
            'version': current.version.toString(),
            'menuName': currentMenu.name,
            'type': 'text',
          });
        }
      }
    }

    return history;
  }

  @override
  Widget build(BuildContext context) {
    final history = _extractMenuHistory();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        color: Colors.white,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            scrollController.addListener(() {
              if (scrollController.position.pixels >=
                  scrollController.position.maxScrollExtent - 100 &&
                  !_isLoading &&
                  _hasMore) {
                _loadMoreVersions();
              }
            });

            return Padding(
              padding: const EdgeInsets.all(16),
              child: history.isEmpty
                  ? const Center(child: Text('메뉴 변경 이력이 없습니다.'))
                  : ListView.builder(
                controller: scrollController,
                itemCount: history.length + (_isLoading ? 2 : 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '메뉴 수정 이력',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  final realIndex = index - 1;

                  if (realIndex >= history.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final item = history[realIndex];
                  final version = _versions.firstWhere(
                        (v) => v.version.toString() == item['version'],
                    orElse: () => _versions.first,
                  );

                  final editorId = int.tryParse(item['editorId'] ?? '');
                  final editorName = item['editor'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: editorId != null &&
                              widget.onTapEditor != null
                              ? () => widget.onTapEditor!(
                              editorId, editorName)
                              : null,
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              children: [
                                TextSpan(
                                  text: editorName,
                                  style: const TextStyle(
                                      decoration:
                                      TextDecoration.underline),
                                ),
                                TextSpan(text: ' • ${item['date']}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '메뉴: ${item['menuName']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),

                        /// ✅ 이미지 비교인 경우
                        if (item['type'] == 'image') ...[
                          const Text(
                            '이미지 변경',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('이전 이미지',
                                        style: TextStyle(fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 140,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                        border: Border.all(
                                            color:
                                            Colors.grey.shade300),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: item['old']!.isNotEmpty
                                          ? Image.network(
                                        item['old']!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder:
                                            (_, __, ___) =>
                                        const Icon(
                                            Icons
                                                .broken_image,
                                            size: 40),
                                      )
                                          : Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                              Icons.broken_image,
                                              size: 40),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('변경된 이미지',
                                        style: TextStyle(fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 140,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                        border: Border.all(
                                            color:
                                            Colors.grey.shade300),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Image.network(
                                        item['new']!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) =>
                                        const Icon(
                                            Icons.broken_image,
                                            size: 40),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          /// ✅ 텍스트 변경은 그대로
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black),
                              children: [
                                TextSpan(text: '${item['field']}: '),
                                if (item['old']!.isNotEmpty)
                                  TextSpan(
                                    text: '${item['old']} → ',
                                    style: const TextStyle(
                                      decoration:
                                      TextDecoration.lineThrough,
                                      color: Colors.red,
                                    ),
                                  ),
                                TextSpan(
                                  text: item['new'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                widget.onRestore?.call(version),
                            child: const Text(
                              '이전 버전으로 되돌리기',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

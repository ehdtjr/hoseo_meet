import 'package:flutter/material.dart';
import '../../../../data/models/restaurant/restaurant_menmu_version.dart';

class MenuHistoryBottomSheet extends StatefulWidget {
  final Future<List<RestaurantMenuVersion>> Function({
  required int skip,
  required int limit,
  }) fetchVersions;

  final void Function(RestaurantMenuVersion version)? onRestore;
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
  final ScrollController _scrollController = ScrollController();

  final List<RestaurantMenuVersion> _versions = [];
  final List<Map<String, dynamic>> _history = [];

  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMoreVersions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 스크롤이 끝에 가까워지면 더 불러오기
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreVersions();
    }
  }

  /// 버전 추가 로딩
  Future<void> _loadMoreVersions() async {
    setState(() => _isLoading = true);

    final newVersions = await widget.fetchVersions(
      skip: _skip,
      limit: _limit,
    );

    if (newVersions.isEmpty) {
      _hasMore = false;
    } else {
      // 최신순 정렬
      newVersions.sort((a, b) => b.version.compareTo(a.version));

      final List<Map<String, dynamic>> newHistory = [];
      for (int i = 0; i < newVersions.length - 1; i++) {
        final diffs = _getDiffs(newVersions[i], newVersions[i + 1]);
        if (diffs.isNotEmpty) {
          newHistory.add({
            'date': newVersions[i].createdAt.toString(),
            'editorId': newVersions[i].editorId.toString(),
            'editor': widget.editorNames[newVersions[i].editorId] ??
                '사용자 ${newVersions[i].editorId}',
            'version': newVersions[i].version.toString(),
            'diffs': diffs,
          });
        }
      }

      setState(() {
        _versions.addAll(newVersions);
        _history.addAll(newHistory);
        _skip += newVersions.length;
      });
    }

    setState(() => _isLoading = false);
  }

  /// 버전 간 diff 계산
  List<Map<String, String>> _getDiffs(
      RestaurantMenuVersion curr, RestaurantMenuVersion prev) {
    final List<Map<String, String>> diffs = [];

    final currIds = curr.menus.map((m) => m.id).toSet();
    final prevIds = prev.menus.map((m) => m.id).toSet();

    for (final currMenu in curr.menus) {
      final prevMenu = prev.menus
          .where((m) => m.id == currMenu.id)
          .isNotEmpty
          ? prev.menus.firstWhere((m) => m.id == currMenu.id)
          : null;

      void compareField(String label, String? oldVal, String? newVal) {
        if ((oldVal ?? '').trim() != (newVal ?? '').trim()) {
          diffs.add({
            'field': label,
            'old': oldVal ?? '',
            'new': newVal ?? '',
            'menuName': currMenu.name,
            'type': label == '이미지' ? 'image' : 'text',
          });
        }
      }

      if (prevMenu != null) {
        compareField('이름', prevMenu.name, currMenu.name);
        compareField('가격', prevMenu.price.toString(), currMenu.price.toString());
        compareField('이미지', prevMenu.image, currMenu.image);
      } else {
        diffs.add({
          'field': '메뉴 추가됨',
          'old': '',
          'new': currMenu.name,
          'menuName': currMenu.name,
          'type': 'text',
        });
      }
    }

    final deletedIds = prevIds.difference(currIds);
    for (final deletedId in deletedIds) {
      final deletedMenu = prev.menus.firstWhere((m) => m.id == deletedId);
      diffs.add({
        'field': '메뉴 삭제됨',
        'old': deletedMenu.name,
        'new': '',
        'menuName': deletedMenu.name,
        'type': 'text',
      });
    }

    return diffs;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        color: Colors.white,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _history.isEmpty && _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _history.isEmpty
                  ? const Center(child: Text('메뉴 변경 이력이 없습니다.'))
                  : ListView.builder(
                controller: _scrollController,
                itemCount: _history.length + (_hasMore ? 2 : 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '메뉴 수정 이력',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  if (index == _history.length + 1 && _hasMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final item = _history[index - 1];
                  final version = _versions.firstWhere(
                        (v) => v.version.toString() == item['version'],
                    orElse: () => _versions.first,
                  );

                  final editorId = int.tryParse(item['editorId'] ?? '');
                  final editorName = item['editor'] ?? '';
                  final diffs = item['diffs'] as List<dynamic>;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            offset: const Offset(0, 2),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
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
                                      fontSize: 12,
                                      color: Colors.grey),
                                  children: [
                                    TextSpan(
                                      text: editorName,
                                      style: const TextStyle(
                                          decoration: TextDecoration
                                              .underline),
                                    ),
                                    TextSpan(
                                        text: ' • ${item['date']}'),
                                    TextSpan(
                                        text:
                                        ' • 버전 ${item['version']}')
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...diffs.map((diff) {
                              if (diff['type'] == 'image') {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${diff['menuName']} - 이미지 변경',
                                        style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                const Text('이전 이미지',
                                                    style: TextStyle(
                                                        fontSize:
                                                        11)),
                                                const SizedBox(
                                                    height: 4),
                                                Container(
                                                  height: 100,
                                                  decoration:
                                                  BoxDecoration(
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                        8),
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300),
                                                  ),
                                                  clipBehavior:
                                                  Clip.hardEdge,
                                                  child: diff['old']!
                                                      .isNotEmpty
                                                      ? Image.network(
                                                    diff['old']!,
                                                    fit: BoxFit
                                                        .cover,
                                                    width: double
                                                        .infinity,
                                                    errorBuilder: (_,
                                                        __,
                                                        ___) =>
                                                    const Icon(
                                                        Icons
                                                            .broken_image,
                                                        size:
                                                        40),
                                                  )
                                                      : Container(
                                                    color: Colors
                                                        .grey[200],
                                                    child:
                                                    const Center(
                                                      child: Icon(
                                                          Icons
                                                              .broken_image,
                                                          size:
                                                          40),
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
                                                    style: TextStyle(
                                                        fontSize:
                                                        11)),
                                                const SizedBox(
                                                    height: 4),
                                                Container(
                                                  height: 100,
                                                  decoration:
                                                  BoxDecoration(
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                        8),
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300),
                                                  ),
                                                  clipBehavior:
                                                  Clip.hardEdge,
                                                  child: Image.network(
                                                    diff['new']!,
                                                    fit: BoxFit.cover,
                                                    width:
                                                    double.infinity,
                                                    errorBuilder: (_,
                                                        __, ___) =>
                                                    const Icon(Icons
                                                        .broken_image,
                                                        size: 40),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                if (diff['field'] == '메뉴 추가됨') {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 4),
                                    child: Text(
                                      '메뉴 추가됨: ${diff['menuName']}',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 13),
                                    ),
                                  );
                                } else if (diff['field'] ==
                                    '메뉴 삭제됨') {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 4),
                                    child: Text(
                                      '메뉴 삭제됨: ${diff['menuName']}',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 13),
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 4),
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black),
                                        children: [
                                          TextSpan(
                                              text:
                                              '${diff['menuName']} ${diff['field']}: '),
                                          if (diff['old']!.isNotEmpty)
                                            TextSpan(
                                              text:
                                              '${diff['old']} → ',
                                              style: const TextStyle(
                                                decoration:
                                                TextDecoration
                                                    .lineThrough,
                                                color: Colors.red,
                                              ),
                                            ),
                                          TextSpan(
                                            text: diff['new'] ?? '',
                                            style: const TextStyle(
                                                color: Colors.green),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              }
                            }).toList(),
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
                      ),
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

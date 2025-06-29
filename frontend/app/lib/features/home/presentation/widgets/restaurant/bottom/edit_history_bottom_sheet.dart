import 'package:flutter/material.dart';
import '../../../../data/models/restaurant/restaurant_version.dart';

class EditHistoryBottomSheet extends StatefulWidget {
  final Future<List<RestaurantVersion>> Function({
  required int skip,
  required int limit,
  }) fetchVersions;

  final void Function(RestaurantVersion version)? onRestore;
  final void Function(int userId)? onTapEditor;
  final Map<int, String> editorNames;

  const EditHistoryBottomSheet({
    super.key,
    required this.fetchVersions,
    required this.editorNames,
    this.onRestore,
    this.onTapEditor,
  });

  @override
  State<EditHistoryBottomSheet> createState() => _EditHistoryBottomSheetState();
}

class _EditHistoryBottomSheetState extends State<EditHistoryBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<RestaurantVersion> _versions = [];
  final List<Map<String, dynamic>> _history = [];

  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 10;

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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreVersions();
    }
  }

  Future<void> _loadMoreVersions() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final fetched = await widget.fetchVersions(
      skip: _versions.length,
      limit: _limit,
    );

    if (fetched.isEmpty) {
      _hasMore = false;
    } else {
      fetched.sort((a, b) => b.version.compareTo(a.version));

      final List<Map<String, dynamic>> newHistory = [];

      for (int i = 0; i < fetched.length - 1; i++) {
        final current = fetched[i];
        final previous = fetched[i + 1];
        final List<Map<String, String>> diffs = [];

        void compareField(String label, String? oldVal, String? newVal) {
          if ((oldVal ?? '').trim() != (newVal ?? '').trim()) {
            diffs.add({
              'field': label,
              'old': oldVal ?? '',
              'new': newVal ?? '',
              'type': 'text',
            });
          }
        }

        compareField('이름', previous.name, current.name);
        compareField('주소', previous.address, current.address);
        compareField('연락처', previous.contact, current.contact);
        compareField('영업시간', previous.businessHours, current.businessHours);

        final oldLoc = '${previous.latitude}, ${previous.longitude}';
        final newLoc = '${current.latitude}, ${current.longitude}';
        compareField('위치', oldLoc, newLoc);

        if (diffs.isNotEmpty) {
          newHistory.add({
            'date': current.createdAt.toString(),
            'editorId': current.editorId.toString(),
            'editor': widget.editorNames[current.editorId] ?? '사용자 ${current.editorId}',
            'version': current.version.toString(),
            'diffs': diffs,
          });
        }
      }

      setState(() {
        _versions.addAll(fetched);
        _history.addAll(newHistory);
      });

      if (fetched.length < _limit) {
        _hasMore = false;
      }
    }

    setState(() => _isLoading = false);
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
                  ? const Center(child: Text('변경된 이력이 없습니다.'))
                  : ListView.builder(
                controller: _scrollController,
                itemCount: _history.length + (_hasMore ? 2 : 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '수정 이력',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  final realIndex = index - 1;

                  if (realIndex >= _history.length && _hasMore) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  if (realIndex >= _history.length) {
                    return const SizedBox.shrink();
                  }

                  final item = _history[realIndex];
                  final version = _versions.firstWhere(
                        (v) => v.version.toString() == item['version'],
                    orElse: () => _versions.first,
                  );
                  final editorId = int.tryParse(item['editorId'] ?? '');
                  final diffs = item['diffs'] as List<dynamic>;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: editorId != null && widget.onTapEditor != null
                                  ? () => widget.onTapEditor!(editorId)
                                  : null,
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  children: [
                                    TextSpan(
                                      text: item['editor'],
                                      style: const TextStyle(decoration: TextDecoration.underline),
                                    ),
                                    TextSpan(text: ' • ${item['date']}'),
                                    TextSpan(text: ' • 버전 ${item['version']}'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...diffs.map((diff) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    children: [
                                      TextSpan(text: '${diff['field']}: '),
                                      if (diff['old']!.isNotEmpty)
                                        TextSpan(
                                          text: '${diff['old']} → ',
                                          style: const TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            color: Colors.red,
                                          ),
                                        ),
                                      TextSpan(
                                        text: diff['new'] ?? '',
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => widget.onRestore?.call(version),
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

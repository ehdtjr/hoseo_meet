import 'package:flutter/material.dart';
import '../../../../data/models/restaurant/restaurant_version.dart';

class EditHistoryBottomSheet extends StatefulWidget {
  final Future<List<RestaurantVersion>> Function({required int skip, required int limit}) fetchVersions;
  final void Function(RestaurantVersion version)? onRestore;
  final Map<int, String> editorNames;
  final void Function(int userId)? onTapEditor;

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
  final List<RestaurantVersion> _versions = [];
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
    final fetched = await widget.fetchVersions(skip: _versions.length, limit: _limit);
    setState(() {
      _versions.addAll(fetched);
      _isLoading = false;
      if (fetched.length < _limit) _hasMore = false;
    });
  }

  List<Map<String, String>> _extractEditHistory() {
    final List<Map<String, String>> history = [];

    for (int i = 0; i < _versions.length - 1; i++) {
      final current = _versions[i];
      final previous = _versions[i + 1];

      void compareField(String label, String? oldVal, String? newVal) {
        if ((oldVal ?? '').trim() != (newVal ?? '').trim()) {
          history.add({
            'date': current.createdAt.toString(),
            'editorId': current.editorId.toString(),
            'editor': widget.editorNames[current.editorId] ?? '사용자 ${current.editorId}',
            'field': label,
            'old': oldVal ?? '',
            'new': newVal ?? '',
            'version': current.version.toString(),
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
    }

    return history;
  }

  @override
  Widget build(BuildContext context) {
    final history = _extractEditHistory();

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
            // 무한스크롤 연결
            scrollController.addListener(() {
              if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 100 &&
                  !_isLoading &&
                  _hasMore) {
                _loadMoreVersions();
              }
            });

            return Padding(
              padding: const EdgeInsets.all(16),
              child: history.isEmpty
                  ? const Center(child: Text('변경된 이력이 없습니다.'))
                  : ListView.builder(
                controller: scrollController,
                itemCount: history.length + (_isLoading ? 2 : 1),
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

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            children: [
                              TextSpan(text: '${item['field']} 변경: '),
                              TextSpan(
                                text: '${item['old']} → ',
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.red,
                                ),
                              ),
                              TextSpan(
                                text: item['new'] ?? '',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ),
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

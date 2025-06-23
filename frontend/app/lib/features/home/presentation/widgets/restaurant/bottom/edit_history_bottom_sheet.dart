import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EditHistoryBottomSheet extends StatelessWidget {
  final List<Map<String, String>> history;

  const EditHistoryBottomSheet({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            controller: scrollController,
            itemCount: history.length + 1,
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
              final item = history[index - 1];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['date'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

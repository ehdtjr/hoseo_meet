import 'package:flutter/material.dart';

class RatingOverview extends StatelessWidget {
  const RatingOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center, // 가운데 정렬
          children: [
            const Text(
              "4.0",
              style: TextStyle(
                fontSize: 21,
                color: Color(0xFF2F2F2F),
              ),
            ),
            const SizedBox(height: 4), // 텍스트와 별 간의 간격
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // 별의 가운데 정렬
              children: List.generate(5, (index) {
                return Icon(
                  index < 4
                      ? Icons.star
                      : Icons.star_border, // 별표 개수에 따라 채움/비움
                  color: Colors.red,
                  size: 24,
                );
              }),
            ),
            const SizedBox(height: 10), // 별과 "별점" 텍스트 간의 간격
            const Text(
              "(17)",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        )
        ,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: List.generate(5, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Text(
                      "${5 - index}점",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5 - index,
                      child: Container(
                        height: 8,
                        color: Colors.red,
                      ),
                    ),
                    Expanded(
                      flex: index + 1,
                      child: Container(
                        height: 8,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

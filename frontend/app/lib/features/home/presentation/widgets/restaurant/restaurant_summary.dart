import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/restaurant/restaurant_post_detail.dart';
import '../../../providers/restaurant/restaurant_post_provider.dart';

class RestaurantSummarySection extends ConsumerStatefulWidget {
  final RestaurantPostDetail restaurant;
  final void Function(RestaurantPostDetail updated)? onUpdate;

  const RestaurantSummarySection({
    super.key,
    required this.restaurant,
    this.onUpdate,
  });

  @override
  ConsumerState<RestaurantSummarySection> createState() =>
      _RestaurantSummarySectionState();
}

class _RestaurantSummarySectionState
    extends ConsumerState<RestaurantSummarySection> {
  bool _isEditingName = false;
  late TextEditingController _nameController;
  late RestaurantPostDetail _restaurant;

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant;
    _nameController = TextEditingController(text: _restaurant.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != _restaurant.name) {
      final updated = _restaurant.copyWith(name: newName);
      widget.onUpdate?.call(updated);

      setState(() {
        _restaurant = updated;
      });
    }
    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(restaurantEditModeProvider);
    final fakeComment = _restaurant.comment?.trim().isNotEmpty == true
        ? _restaurant.comment!
        : '신선한 재료로 만든 건강한 맛, 최고의 맛집!';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⛳ 가게 이름 (중앙 고정 + 우측에 아이콘 분리 배치)
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 중앙 텍스트 또는 TextField
                Center(
                  child: _isEditingName
                      ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                        EdgeInsets.symmetric(vertical: 4),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  )
                      : Text(
                    _restaurant.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                // 우측 아이콘 (수정/확인/취소)
                if (isEditMode)
                  Positioned(
                    right: 0,
                    child: _isEditingName
                        ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check,
                              size: 18, color: Colors.green),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _saveName,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.red),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _nameController.text = _restaurant.name;
                            setState(() => _isEditingName = false);
                          },
                        ),
                      ],
                    )
                        : IconButton(
                      icon: const Icon(Icons.edit,
                          size: 18, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          setState(() => _isEditingName = true),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '음식점',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888), height: 1.3),
          ),
          const SizedBox(height: 8),

          // ⭐ 별점
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                final isFilled = index < _restaurant.avgRating.floor();
                final isHalf = index < _restaurant.avgRating &&
                    index >= _restaurant.avgRating.floor();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    isFilled
                        ? Icons.star
                        : isHalf
                        ? Icons.star_half
                        : Icons.star_border,
                    size: 24,
                    color: Colors.redAccent,
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '(${_restaurant.reviewCount})',
                style:
                const TextStyle(fontSize: 13, color: Color(0xFF555555)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 💬 코멘트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '"$fakeComment"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

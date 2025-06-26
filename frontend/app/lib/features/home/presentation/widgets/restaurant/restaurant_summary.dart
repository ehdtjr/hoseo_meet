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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.restaurant.name);
  }

  @override
  void didUpdateWidget(covariant RestaurantSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 name이 바뀌었을 때 컨트롤러 업데이트
    if (oldWidget.restaurant.name != widget.restaurant.name) {
      _nameController.text = widget.restaurant.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.restaurant.name) {
      final updated = widget.restaurant.copyWith(name: newName);
      widget.onUpdate?.call(updated);
    }
    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(restaurantEditModeProvider);
    final restaurant = widget.restaurant;

    final fakeComment = restaurant.comment?.trim().isNotEmpty == true
        ? restaurant.comment!
        : '신선한 재료로 만든 건강한 맛, 최고의 맛집!';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⛳ 가게 이름
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
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
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  )
                      : Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
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
                            _nameController.text = restaurant.name;
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
                final isFilled = index < restaurant.avgRating.floor();
                final isHalf = index < restaurant.avgRating &&
                    index >= restaurant.avgRating.floor();

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
                '(${restaurant.reviewCount})',
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
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

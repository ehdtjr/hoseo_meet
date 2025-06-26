import 'package:flutter/material.dart';
import '../../../../data/models/restaurant/restaurant_menu.dart';

class MenuItemCard extends StatelessWidget {
  final RestaurantMenu menu;

  const MenuItemCard({super.key, required this.menu});

  @override
  Widget build(BuildContext context) {
    final isValidImage = menu.image.isNotEmpty && menu.image.startsWith('http');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isValidImage
                ? Image.network(
              menu.image,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderImage(),
            )
                : _placeholderImage(),
          ),
          const SizedBox(width: 20),
          // 텍스트
          Expanded(
            child: SizedBox(
              height: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menu.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black, // 검정색
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${menu.price}원',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black, // 검정색
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[300],
      child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 36),
    );
  }
}

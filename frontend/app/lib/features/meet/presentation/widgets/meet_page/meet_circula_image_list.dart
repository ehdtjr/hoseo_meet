import 'package:flutter/material.dart';
import 'add_new_circular_image_widget.dart';

class MeetCircularImageList extends StatelessWidget {
  final List<String> imageUrls = [
    'https://t1.daumcdn.net/thumb/R720x0/?fname=http://t1.daumcdn.net/brunch/service/user/4Khk/image/ZcJXAY7tBCORa_ZCYpVfWQM66IU.jpg',
    'https://t1.daumcdn.net/thumb/R720x0/?fname=http://t1.daumcdn.net/brunch/service/user/4Khk/image/ZcJXAY7tBCORa_ZCYpVfWQM66IU.jpg',
    'https://t1.daumcdn.net/thumb/R720x0/?fname=http://t1.daumcdn.net/brunch/service/user/4Khk/image/ZcJXAY7tBCORa_ZCYpVfWQM66IU.jpg',
    'https://t1.daumcdn.net/thumb/R720x0/?fname=http://t1.daumcdn.net/brunch/service/user/4Khk/image/ZcJXAY7tBCORa_ZCYpVfWQM66IU.jpg',
    'https://t1.daumcdn.net/thumb/R720x0/?fname=http://t1.daumcdn.net/brunch/service/user/4Khk/image/ZcJXAY7tBCORa_ZCYpVfWQM66IU.jpg'
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: index == 0
                ? AddNewCircularImageWidget()
                : _ImageItemWidget(imageUrl: imageUrls[index]),
          );
        },
      ),
    );
  }
}

class _ImageItemWidget extends StatelessWidget {
  final String imageUrl;

  const _ImageItemWidget({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red, width: 2),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

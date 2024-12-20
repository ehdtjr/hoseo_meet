// lib/widgets/meet_searchbar.dart
import 'package:flutter/material.dart';

class MeetSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  MeetSearchBar({this.controller, this.onChanged, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4.0,
              offset: Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(25.0),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: (value) {
            if (onSubmitted != null) onSubmitted!();
          },
          decoration: InputDecoration(
            suffixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'assets/img/icon/search-icon.png',
                width: 24,
                height: 24,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            isDense: true,
            hintText: '제목, 글 내용, 해시 태그',
          ),
        ),
      ),
    );
  }
}

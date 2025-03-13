import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReviewContentLabel extends StatelessWidget {
  final String label;

  const ReviewContentLabel({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class ReviewContentInput extends StatelessWidget {
  final TextEditingController controller;

  const ReviewContentInput({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      maxLength: 200,
      decoration: InputDecoration(
        hintText: '리뷰 내용',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StarRatingWidget extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double> onRatingChanged;

  const StarRatingWidget({
    Key? key,
    required this.initialRating,
    required this.onRatingChanged,
  }) : super(key: key);

  @override
  _StarRatingWidgetState createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late double _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  IconData _buildStarIcon(int index) {
    if (_rating >= index + 1) {
      return Icons.star;
    } else if (_rating >= index + 0.5) {
      return Icons.star_half;
    } else {
      return Icons.star_border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTapDown: (TapDownDetails details) {
            const halfWidth = 16.0; // 버튼의 절반 너비
            setState(() {
              if (details.localPosition.dx < halfWidth) {
                _rating = index + 0.5;
              } else {
                _rating = index + 1.0;
              }
              widget.onRatingChanged(_rating);
            });
          },
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              _buildStarIcon(index),
              color: Colors.red,
              size: 32,
            ),
          ),
        );
      }),
    );
  }
}
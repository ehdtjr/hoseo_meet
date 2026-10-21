import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MeetSearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback onClear;

  const MeetSearchBarWidget({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  @override
  _MeetSearchBarWidgetState createState() => _MeetSearchBarWidgetState();
}

class _MeetSearchBarWidgetState extends State<MeetSearchBarWidget> {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // 텍스트 변경 시 UI 업데이트 (Clear 버튼 표시)
  }

  void _handleTextChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6.4,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: _handleTextChanged,
                style: const TextStyle(
                  color: Color(0xFF707070),
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                ),
                decoration: const InputDecoration(
                  hintText: '찾으시는 채팅방이 있나요?',
                  hintStyle: TextStyle(
                    color: Color(0xFF707070),
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 13.0),
                ),
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              GestureDetector(
                onTap: widget.onClear,
                child: const Icon(
                  Icons.clear,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/icons/fi-rr-search.svg',
              width: 20,
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}

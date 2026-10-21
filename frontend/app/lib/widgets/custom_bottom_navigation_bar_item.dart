import 'package:flutter/material.dart';

class CustomBottomNavigationBarItem {
  static BottomNavigationBarItem build({
    required String assetPath,
    required String activeAssetPath,
    required String label,
    required bool isActive,
  }) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(top: 8.0),  // 상단에 8.0의 여백 추가
        child: Image.asset(
          isActive ? activeAssetPath : assetPath,
          width: 30,
          height: 30,
        ),
      ),
      label: label,
    );
  }
}

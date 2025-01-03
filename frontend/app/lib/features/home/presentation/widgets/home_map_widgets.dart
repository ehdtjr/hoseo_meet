import 'package:flutter/cupertino.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class HomeMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return        NaverMap(
      options: const NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(37.5666102, 126.9783881),
          zoom: 15,
        ),
        scrollGesturesEnable: true,
        zoomGesturesEnable: true,
        rotationGesturesEnable: true,
      ),
    );
  }
}

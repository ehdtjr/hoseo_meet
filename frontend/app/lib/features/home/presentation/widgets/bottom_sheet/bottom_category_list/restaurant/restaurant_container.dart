import 'package:campusmeet/features/home/presentation/widgets/bottom_sheet/bottom_category_list/restaurant/restaurant_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/restaurant/restaurant_post_provider.dart';


class RestaurantContainerWidget extends ConsumerStatefulWidget {
  const RestaurantContainerWidget({super.key});

  @override
  _RestaurantContainerWidgetState createState() => _RestaurantContainerWidgetState();
}

class _RestaurantContainerWidgetState extends ConsumerState<RestaurantContainerWidget> {
  bool isLoading = false;
  bool hasMore = true;
  bool _isDisposed = false;

  late final notifier = ref.read(restaurantPostProvider.notifier);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isDisposed) return;

    setState(() {
      isLoading = true;
    });

    await notifier.resetAndLoad();

    if (_isDisposed) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: const RestaurantList(),
    );
  }
}

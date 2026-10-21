import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/restaurant/menu/restaurant_menu_provider.dart';
import 'menu_add_showbutton.dart';
import 'menu_item.dart';

class MenuSection extends ConsumerStatefulWidget {
  final int postId;

  const MenuSection({super.key, required this.postId});

  @override
  ConsumerState<MenuSection> createState() => _MenuSectionState();
}

class _MenuSectionState extends ConsumerState<MenuSection> {
  bool _didLoad = false;
  int visibleCount = 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(restaurantMenuProvider.notifier).loadMenus(widget.postId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(restaurantMenuProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "메뉴",
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        menuState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('에러 발생: $error'),
          data: (state) {
            final menus = state.menus;

            if (menus.isEmpty) {
              return const Text("등록된 메뉴가 없습니다.");
            }

            final visibleMenus = menus.take(visibleCount).toList();
            final hasMore = menus.length > visibleCount;

            return Column(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleMenus.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final menu = visibleMenus[index];
                    return MenuItemCard(menu: menu); // IconButton 제거됨
                  },
                ),
                const SizedBox(height: 16),
                if (hasMore)
                  AddShowButton(
                    onPressed: () {
                      setState(() {
                        visibleCount += 5;
                      });
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

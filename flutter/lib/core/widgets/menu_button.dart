import 'package:flutter/material.dart';

class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () {
        final scaffold = context.findAncestorStateOfType<ScaffoldState>();
        scaffold?.openDrawer();
      },
    );
  }
}

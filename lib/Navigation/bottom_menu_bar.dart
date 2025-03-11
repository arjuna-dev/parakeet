import 'package:flutter/material.dart';

class BottomMenuBar extends StatelessWidget {
  final String currentRoute;

  const BottomMenuBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    print('Current route in BottomMenuBar: $currentRoute');

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.favorite, size: 24),
            onPressed: () {
              if (currentRoute != '/favorite') {
                Navigator.pushReplacementNamed(context, '/favorite');
              }
            },
            color: currentRoute == '/favorite' ? colorScheme.primary : null,
          ),
          IconButton(
            icon: const Icon(Icons.library_add, size: 24),
            onPressed: () {
              if (currentRoute != '/create_lesson') {
                Navigator.pushReplacementNamed(context, '/create_lesson');
              }
            },
            color: currentRoute == '/create_lesson' ? colorScheme.primary : null,
          ),
          IconButton(
            icon: const Icon(Icons.library_music, size: 24),
            onPressed: () {
              if (currentRoute != '/library') {
                Navigator.pushReplacementNamed(context, '/library');
              }
            },
            color: currentRoute == '/library' ? colorScheme.primary : null,
          )
        ],
      ),
    );
  }
}

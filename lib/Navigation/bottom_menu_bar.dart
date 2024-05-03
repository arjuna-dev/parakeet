import 'package:flutter/material.dart';

class BottomMenuBar extends StatelessWidget {
  final String currentRoute;

  const BottomMenuBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              if (currentRoute != '/') {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            color: currentRoute == '/' ? Colors.blue : null,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              if (currentRoute != '/create_lesson') {
                Navigator.pushReplacementNamed(context, '/create_lesson');
              }
            },
            color: currentRoute == '/create_lesson' ? Colors.blue : null,
          ),
          IconButton(
            icon: const Icon(Icons.explore),
            onPressed: () {
              if (currentRoute != '/library') {
                Navigator.pushReplacementNamed(context, '/library');
              }
            },
            color: currentRoute == '/library' ? Colors.blue : null,
          )
        ],
      ),
    );
  }
}

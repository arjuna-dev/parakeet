import 'package:flutter/material.dart';

class BottomMenuBar extends StatelessWidget {
  final String currentRoute;

  const BottomMenuBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    print('Current route in BottomMenuBar: $currentRoute');

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              if (currentRoute != '/favorite') {
                Navigator.pushReplacementNamed(context, '/favorite');
              }
            },
            color: currentRoute == '/favorite' ? const Color.fromARGB(255, 187, 134, 252) : null,
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              if (currentRoute != '/create_lesson') {
                Navigator.pushReplacementNamed(context, '/create_lesson');
              }
            },
            color: currentRoute == '/create_lesson' ? const Color.fromARGB(255, 187, 134, 252) : null,
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            onPressed: () {
              if (currentRoute != '/library') {
                Navigator.pushReplacementNamed(context, '/library');
              }
            },
            color: currentRoute == '/library' ? const Color.fromARGB(255, 187, 134, 252) : null,
          )
        ],
      ),
    );
  }
}

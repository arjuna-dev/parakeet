import 'package:flutter/material.dart';

class BottomMenuBar extends StatelessWidget {
  const BottomMenuBar({
    super.key,
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
              if (ModalRoute.of(context)?.settings.name != '/') {
                Navigator.pushNamed(context, '/');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/create_lesson');
            },
          ),
          IconButton(
            icon: const Icon(Icons.explore),
            onPressed: () {
              Navigator.pushNamed(context, '/library');
            },
          )
        ],
      ),
    );
  }
}

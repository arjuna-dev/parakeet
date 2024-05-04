import 'package:flutter/material.dart';

class FinalScript extends StatelessWidget {
  const FinalScript({super.key, required this.script});

  final Map<String, dynamic> script;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Final script'),
        ),
        body: Center(
          child: Text(script.toString()),
        ));
  }
}

import 'package:flutter/material.dart';
import 'package:auralearn/services/audio_player.dart';

class FinalScript extends StatelessWidget {
  const FinalScript(
      {super.key, required this.script, required this.responseDbId});

  final Map<String, dynamic> script;
  final String responseDbId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Final script'),
        ),
        body: Center(
          child: FutureBuilder<void>(
            future:
                AudioPlayerService().playAudioFromScript(script, responseDbId),
            builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(); // Replace with your desired loading widget
              } else if (snapshot.hasError) {
                return Text(
                    'Error: ${snapshot.error}'); // Replace with your desired error widget
              } else {
                return const SizedBox
                    .shrink(); // Replace with your desired widget when the future completes successfully
              }
            },
          ),
        ));
  }
}

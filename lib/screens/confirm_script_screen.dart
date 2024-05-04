import 'package:flutter/material.dart';

class ConfirmScript extends StatelessWidget {
  const ConfirmScript({super.key, required this.script});

  final Map<String, dynamic> script;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Script'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Topic'),
                      subtitle: Text(script['title'] ?? "No title"),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: script['all_turns'].length,
                      itemBuilder: (context, index) {
                        final turn = script['all_turns'][index];
                        return ListTile(
                          title: Text('Sentence Number: ${turn['turn_nr']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(turn['native_language'] ??
                                  "No native language"),
                              Text(turn['target_language'] ??
                                  "No target language"),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print("confirmed");
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:parakeet/services/speech_recognition_service.dart';

// class SpeechRecognitionToggle extends StatelessWidget {
//   final SpeechRecognitionService speechRecognitionService;
//   final ValueNotifier<bool> isActive;
//   final Function(bool) onToggle;

//   const SpeechRecognitionToggle({
//     Key? key,
//     required this.speechRecognitionService,
//     required this.isActive,
//     required this.onToggle,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         const Text('check pronunciation:'),
//         ValueListenableBuilder<bool>(
//           valueListenable: isActive,
//           builder: (context, active, child) {
//             return Switch(
//               value: active,
//               onChanged: (bool value) {
//                 onToggle(value);
//               },
//             );
//           },
//         ),
//       ],
//     );
//   }
// }

// class LanguageNotSupportedDialog extends StatelessWidget {
//   final String targetLanguage;
//   final VoidCallback onDismiss;

//   const LanguageNotSupportedDialog({
//     Key? key,
//     required this.targetLanguage,
//     required this.onDismiss,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Speech Recognition Not Supported'),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text("$targetLanguage is not supported for speech recognition on your device, but we're working on it!"),
//           const SizedBox(height: 8),
//         ],
//       ),
//       actions: [
//         TextButton(
//           child: const Text('OK'),
//           onPressed: () {
//             Navigator.of(context).pop();
//             onDismiss();
//           },
//         ),
//       ],
//     );
//   }
// }

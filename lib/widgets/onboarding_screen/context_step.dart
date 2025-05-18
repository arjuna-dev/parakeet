import 'package:flutter/material.dart';

class ContextStep extends StatelessWidget {
  const ContextStep({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/context.png',
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Hear the Language, Live the Context',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'Immerse yourself! Our unique system generates audio lessons relevant to your interests and real-life situations. Learn vocabulary and grammar naturally, just by listening. Perfect for your commute, workout, or downtime.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

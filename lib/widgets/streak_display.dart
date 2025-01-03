import 'package:flutter/material.dart';
import 'package:parakeet/services/streak_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakDisplay extends StatelessWidget {
  final StreakService _streakService = StreakService();

  StreakDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<List<bool>>(
      future: _streakService.getLast7DaysActivity(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final activityList = snapshot.data!;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        FutureBuilder<int>(
                          future: _streakService.getCurrentStreak(userId),
                          builder: (context, streakSnapshot) {
                            final streak = streakSnapshot.data ?? 0;
                            return Text(
                              '$streak day streak',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (index) {
                    // Reverse the index to show oldest to newest
                    final reversedIndex = 6 - index;
                    final isActive = activityList[reversedIndex];
                    final date = DateTime.now().subtract(Duration(days: 6 - index));
                    final isToday = index == 6;

                    return Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: isToday
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: isActive
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getShortDayName(date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getShortDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}

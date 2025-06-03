import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:parakeet/utils/spaced_repetition_fsrs.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/streak_service.dart';

class ReviewWordsDialog extends StatefulWidget {
  final Map<String, DocumentReference> words;
  final String userID;

  const ReviewWordsDialog({
    Key? key,
    required this.words,
    required this.userID,
  }) : super(key: key);

  @override
  State<ReviewWordsDialog> createState() => _ReviewWordsDialogState();
}

class _ReviewWordsDialogState extends State<ReviewWordsDialog> with TickerProviderStateMixin {
  void _logWordsInfo() {}

  int _currentWordIndex = 0;
  final StreakService _streakService = StreakService();
  bool _streakRecorded = false;

  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _progressController;
  late AnimationController _streakController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _streakAnimation;

  @override
  void initState() {
    _logWordsInfo();
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _streakController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _streakAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _streakController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
    _scaleController.forward();
    _updateProgress();
  }

  void _updateProgress() {
    final total = widget.words.keys.toList().length;
    double progress = 0.0;
    if (total > 0) {
      progress = _currentWordIndex / total;
    }
    _progressController.animateTo(progress);
  }

  Future<void> _recordStreakIfCompleted() async {
    if (!_streakRecorded && _currentWordIndex >= widget.words.keys.toList().length) {
      await _streakService.recordDailyActivity(widget.userID);
      _streakRecorded = true;

      // Start streak animation after a short delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _streakController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _progressController.dispose();
    _streakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400 || screenSize.height < 700;
    final isTablet = screenSize.width > 600;
    final isReviewComplete = _currentWordIndex >= widget.words.keys.toList().length;

    // Record streak when review is completed
    if (isReviewComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordStreakIfCompleted();
      });
    }

    return PopScope(
      canPop: isReviewComplete,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Only close if not review complete (otherwise let the "Continue Learning" button handle navigation)
          if (!isReviewComplete) {
            Navigator.of(context).pop();
          }
        },
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              // Animated background particles (subtle)
              ...List.generate(6, (index) => _buildFloatingParticle(index, colorScheme)),

              // Main dialog content with close button
              Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Stack(
                        children: [
                          Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: isTablet ? 48 : (isSmallScreen ? 20 : 32),
                              vertical: isSmallScreen ? 40 : 60,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? 600 : 450,
                              maxHeight: screenSize.height * (isSmallScreen ? 0.85 : 0.8),
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  blurRadius: 40,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Main dialog content
                                  Expanded(
                                    child: isReviewComplete ? _buildCompletionView(colorScheme, isSmallScreen, isTablet) : _buildReviewView(colorScheme, isSmallScreen, isTablet),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingParticle(int index, ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      duration: Duration(seconds: 3 + index),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Positioned(
          left: (index * 70.0 + 50) % MediaQuery.of(context).size.width,
          top: 100 + (value * 200) % (MediaQuery.of(context).size.height - 300),
          child: Opacity(
            opacity: 0.1,
            child: Container(
              width: 4 + (index % 3) * 2,
              height: 4 + (index % 3) * 2,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletionView(ColorScheme colorScheme, bool isSmallScreen, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.1),
            colorScheme.secondaryContainer.withOpacity(0.1),
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 40 : (isSmallScreen ? 24 : 32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: isTablet ? 120 : (isSmallScreen ? 80 : 100),
                      height: isTablet ? 120 : (isSmallScreen ? 80 : 100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.celebration,
                        size: isTablet ? 60 : (isSmallScreen ? 40 : 50),
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: isTablet ? 32 : (isSmallScreen ? 20 : 24)),

              // Success text with animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 20),
                      child: Column(
                        children: [
                          Text(
                            '🎉 Amazing Work!',
                            style: TextStyle(
                              fontSize: isTablet ? 32 : (isSmallScreen ? 24 : 28),
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          Text(
                            'You\'ve completed all ${widget.words.length} word reviews!\nYour progress has been saved.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: isTablet ? 24 : (isSmallScreen ? 16 : 20)),

              // Streak section with animation
              AnimatedBuilder(
                animation: _streakAnimation,
                builder: (context, child) {
                  final animationValue = _streakAnimation.value.clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: animationValue,
                    child: Opacity(
                      opacity: animationValue,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 20 : (isSmallScreen ? 14 : 16)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary.withOpacity(0.1),
                              colorScheme.secondary.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Streak title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: colorScheme.primary,
                                  size: isTablet ? 24 : (isSmallScreen ? 18 : 20),
                                ),
                                SizedBox(width: isSmallScreen ? 4 : 6),
                                Flexible(
                                  child: Text(
                                    'Learning Streak',
                                    style: TextStyle(
                                      fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: isSmallScreen ? 8 : 12),

                            // Current streak display
                            FutureBuilder<int>(
                              future: _streakService.getCurrentStreak(widget.userID),
                              builder: (context, streakSnapshot) {
                                final streak = streakSnapshot.data ?? 0;
                                return TweenAnimationBuilder<int>(
                                  duration: const Duration(milliseconds: 1000),
                                  tween: IntTween(begin: 0, end: streak),
                                  builder: (context, animatedStreak, child) {
                                    return Text(
                                      '$animatedStreak day${animatedStreak == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: isTablet ? 24 : (isSmallScreen ? 18 : 20),
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                            SizedBox(height: isSmallScreen ? 8 : 12),

                            // 7-day activity visualization
                            FutureBuilder<List<bool>>(
                              future: _streakService.getLast7DaysActivity(widget.userID),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return SizedBox(
                                    height: isSmallScreen ? 20 : 24,
                                    width: isSmallScreen ? 20 : 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  );
                                }

                                final activityList = snapshot.data!;
                                return SizedBox(
                                  height: isSmallScreen ? 40 : 50,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(7, (index) {
                                      final reversedIndex = 6 - index;
                                      final isActive = activityList[reversedIndex];
                                      final date = DateTime.now().subtract(Duration(days: 6 - index));
                                      final isToday = index == 6;

                                      return TweenAnimationBuilder<double>(
                                        duration: Duration(milliseconds: 300 + (index * 100)),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        builder: (context, animValue, child) {
                                          final clampedValue = animValue.clamp(0.0, 1.0);
                                          return Transform.scale(
                                            scale: clampedValue,
                                            child: Container(
                                              margin: EdgeInsets.symmetric(
                                                horizontal: isSmallScreen ? 2 : 3,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: isSmallScreen ? 16 : 20,
                                                    height: isSmallScreen ? 16 : 20,
                                                    decoration: BoxDecoration(
                                                      gradient: isActive
                                                          ? LinearGradient(
                                                              colors: [
                                                                colorScheme.primary,
                                                                colorScheme.secondary,
                                                              ],
                                                            )
                                                          : null,
                                                      color: !isActive ? colorScheme.surfaceContainerHighest : null,
                                                      shape: BoxShape.circle,
                                                      border: isToday
                                                          ? Border.all(
                                                              color: colorScheme.primary,
                                                              width: 1.5,
                                                            )
                                                          : null,
                                                      boxShadow: isActive
                                                          ? [
                                                              BoxShadow(
                                                                color: colorScheme.primary.withOpacity(0.3),
                                                                blurRadius: 4,
                                                                spreadRadius: 1,
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    child: isActive
                                                        ? Icon(
                                                            Icons.check,
                                                            color: colorScheme.onPrimary,
                                                            size: isSmallScreen ? 10 : 12,
                                                          )
                                                        : null,
                                                  ),
                                                  SizedBox(height: isSmallScreen ? 2 : 4),
                                                  Text(
                                                    _getShortDayName(date),
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 8 : 9,
                                                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                      color: colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: isTablet ? 24 : (isSmallScreen ? 16 : 20)),

              // Done button with gradient
              Container(
                width: double.infinity,
                height: isTablet ? 56 : (isSmallScreen ? 44 : 52),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/create_lesson',
                        (route) => false,
                      );
                    },
                    child: Center(
                      child: Text(
                        'Continue Learning',
                        style: TextStyle(
                          fontSize: isTablet ? 17 : (isSmallScreen ? 15 : 16),
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getShortDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  Widget _buildReviewView(ColorScheme colorScheme, bool isSmallScreen, bool isTablet) {
    return Column(
      children: [
        // Header with progress and X button
        Container(
          padding: EdgeInsets.all(isTablet ? 32 : (isSmallScreen ? 20 : 24)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withOpacity(0.3),
                colorScheme.secondaryContainer.withOpacity(0.2),
              ],
            ),
          ),
          child: Column(
            children: [
              // X button (only show if not review complete)
              if (_currentWordIndex < widget.words.keys.toList().length)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(isTablet ? 10 : (isSmallScreen ? 6 : 8)),
                          child: Icon(
                            Icons.close,
                            size: isTablet ? 28 : (isSmallScreen ? 20 : 24),
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              // Progress indicator
              Row(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _progressAnimation.value,
                          backgroundColor: colorScheme.outline.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                          minHeight: isSmallScreen ? 6 : 8,
                        );
                      },
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${_currentWordIndex + 1}/${widget.words.keys.toList().length}',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              Text(
                'Vocabulary Review',
                style: TextStyle(
                  fontSize: isTablet ? 24 : (isSmallScreen ? 18 : 20),
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: isSmallScreen ? 4 : 6),
              Text(
                'Rate how well you know this word',
                style: TextStyle(
                  fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Word display with slide animation
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 32 : (isSmallScreen ? 20 : 24)),
            child: Column(
              children: [
                // Word card with animation
                Expanded(
                  flex: 1,
                  child: Center(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          maxHeight: isTablet ? 120 : (isSmallScreen ? 80 : 100),
                        ),
                        padding: EdgeInsets.all(isTablet ? 24 : (isSmallScreen ? 16 : 20)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              colorScheme.surfaceContainerHigh.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.words.keys.toList()[_currentWordIndex],
                            style: TextStyle(
                              fontSize: isTablet ? 32 : (isSmallScreen ? 22 : 28),
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isTablet ? 24 : (isSmallScreen ? 16 : 20)),

                // Review buttons
                Expanded(
                  flex: 2,
                  child: _buildReviewButtons(colorScheme, isSmallScreen, isTablet),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewButtons(ColorScheme colorScheme, bool isSmallScreen, bool isTablet) {
    final buttons = [
      _ReviewButtonData(
        label: 'Forgot',
        icon: Icons.close,
        gradient: [Colors.red.shade400, Colors.red.shade600],
        rating: fsrs.Rating.again,
      ),
      _ReviewButtonData(
        label: 'Hard',
        icon: Icons.trending_down,
        gradient: [Colors.orange.shade400, Colors.orange.shade600],
        rating: fsrs.Rating.hard,
      ),
      _ReviewButtonData(
        label: 'Good',
        icon: Icons.check,
        gradient: [colorScheme.primary, colorScheme.secondary],
        rating: fsrs.Rating.good,
      ),
      _ReviewButtonData(
        label: 'Easy',
        icon: Icons.trending_up,
        gradient: [Colors.green.shade400, Colors.green.shade600],
        rating: fsrs.Rating.easy,
      ),
    ];

    if (isSmallScreen) {
      return Column(
        children: buttons
            .map((button) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildReviewButton(button, colorScheme, isSmallScreen, isTablet),
                  ),
                ))
            .toList(),
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildReviewButton(buttons[0], colorScheme, isSmallScreen, isTablet),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildReviewButton(buttons[1], colorScheme, isSmallScreen, isTablet),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildReviewButton(buttons[2], colorScheme, isSmallScreen, isTablet),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildReviewButton(buttons[3], colorScheme, isSmallScreen, isTablet),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildReviewButton(_ReviewButtonData data, ColorScheme colorScheme, bool isSmallScreen, bool isTablet) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: BoxConstraints(
        minHeight: isTablet ? 80 : (isSmallScreen ? 56 : 68),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: data.gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleReview(data.rating),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : (isSmallScreen ? 12 : 16),
              vertical: isTablet ? 20 : (isSmallScreen ? 12 : 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  data.icon,
                  size: isTablet ? 28 : (isSmallScreen ? 20 : 24),
                  color: Colors.white,
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Flexible(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontSize: isTablet ? 19 : (isSmallScreen ? 15 : 17),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReview(fsrs.Rating rating) async {
    // Reset animations for next word
    _slideController.reset();

    final word = widget.words.keys.toList()[_currentWordIndex];
    final docRef = widget.words[word];

    final docSnapshot = await docRef!.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final wordCard = WordCard.fromFirestore(data);

      final f = fsrs.FSRS();
      final now = DateTime.now();
      final scheduling = f.repeat(wordCard.card, now);
      final newCard = scheduling[rating]!.card;

      final updatedWordCard = WordCard(
        word: word,
        due: newCard.due,
        lastReview: now,
        stability: newCard.stability,
        difficulty: newCard.difficulty,
        elapsedDays: newCard.elapsedDays,
        scheduledDays: newCard.scheduledDays,
        reps: newCard.reps,
        lapses: newCard.lapses,
        state: newCard.state,
      );

      await docRef.set(updatedWordCard.toFirestore(), SetOptions(merge: true));
    }

    setState(() {
      _currentWordIndex++;
    });

    if (_currentWordIndex < widget.words.keys.toList().length) {
      _updateProgress();
      _slideController.forward();
    }
  }
}

class _ReviewButtonData {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final fsrs.Rating rating;

  const _ReviewButtonData({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.rating,
  });
}

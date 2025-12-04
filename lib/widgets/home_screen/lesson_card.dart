import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/category_icons.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/services/audio_player_manager.dart';

class LessonCard extends StatefulWidget {
  final DocumentSnapshot audioFile;
  final VoidCallback? onReload;
  final bool isSmallScreen;
  final bool showCategoryBadge;

  const LessonCard({
    Key? key,
    required this.audioFile,
    this.onReload,
    required this.isSmallScreen,
    this.showCategoryBadge = true,
  }) : super(key: key);

  @override
  State<LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<LessonCard> {
  bool _isPressed = false;
  bool _isDeleting = false;
  bool _isCompleted = false;
  bool _isLoadingCompletion = true;
  int? _lessonLevel;

  AnalyticsManager? _getAnalyticsManager() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return AnalyticsManager(user.uid);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _checkCompletionStatus();
  }

  Future<void> _checkCompletionStatus() async {
    try {
      final parentDocId = widget.audioFile.reference.parent.parent!.id;
      final doc = await FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(parentDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _isCompleted = data['completed'] ?? false;
            _lessonLevel = data['categoryLevel'];
            _isLoadingCompletion = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isCompleted = false;
            _lessonLevel = null;
            _isLoadingCompletion = false;
          });
        }
      }
    } catch (e) {
      print('Error checking completion status: $e');
      if (mounted) {
        setState(() {
          _isCompleted = false;
          _isLoadingCompletion = false;
        });
      }
    }
  }

  String getCategory() {
    final data = widget.audioFile.data() as Map<String, dynamic>?;
    if (data?.containsKey('category') == true &&
        widget.audioFile.get('category') != null &&
        widget.audioFile.get('category').toString().trim().isNotEmpty) {
      return widget.audioFile.get('category');
    }
    return 'Custom Lesson';
  }

  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1
          ? '1 day ago'
          : '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1
          ? '1 hour ago'
          : '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1
          ? '1 minute ago'
          : '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  String _getCreationDateText() {
    try {
      // Try to get creation time from document metadata
      final metadata = widget.audioFile.metadata;
      if (metadata.hasPendingWrites == false) {
        // Try to get from document data first
        final data = widget.audioFile.data() as Map<String, dynamic>?;
        if (data != null) {
          // Check for common date fields
          if (data.containsKey('created_at')) {
            final createdAt = data['created_at'];
            if (createdAt is Timestamp) {
              return _formatDate(createdAt.toDate());
            }
          }
          if (data.containsKey('timestamp')) {
            final timestamp = data['timestamp'];
            if (timestamp is Timestamp) {
              return _formatDate(timestamp.toDate());
            }
          }
          if (data.containsKey('createdAt')) {
            final createdAt = data['createdAt'];
            if (createdAt is Timestamp) {
              return _formatDate(createdAt.toDate());
            }
          }
        }
      }
      
      // Fallback: use current time or a default
      return 'Recently created';
    } catch (e) {
      return 'Recently created';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // If less than a day, show time ago
    if (difference.inDays == 0) {
      return getTimeAgo(date);
    }
    
    // Format as date
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[date.month - 1];
    final day = date.day;
    final year = date.year;
    
    // If same year, don't show year
    if (date.year == now.year) {
      return '$month $day';
    } else {
      return '$month $day, $year';
    }
  }

  String getEstimatedDuration() {
    try {
      final data = widget.audioFile.data() as Map<String, dynamic>?;
      if (data?.containsKey('dialogue') == true) {
        final dialogue = widget.audioFile.get('dialogue') as List<dynamic>?;
        if (dialogue != null && dialogue.isNotEmpty) {
          // Each dialogue turn typically takes about 15-30 seconds
          // Including pauses, repetitions, and explanations, estimate ~2-3 minutes per turn
          final turns = dialogue.length;
          final estimatedMinutes =
              (turns * 2.5).round(); // Average 2.5 minutes per turn

          if (estimatedMinutes < 60) {
            return '~$estimatedMinutes min';
          } else {
            final hours = estimatedMinutes ~/ 60;
            final minutes = estimatedMinutes % 60;
            if (minutes == 0) {
              return '~${hours}h';
            } else {
              return '~${hours}h ${minutes}m';
            }
          }
        }
      }

      // Default fallback for lessons without dialogue data
      return '~10 min';
    } catch (e) {
      return '~10 min';
    }
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'at the coffee shop':
        return const Color(0xFF5D4037);
      case 'weather talk':
        return const Color(0xFF303F9F);
      case 'in the supermarket':
        return const Color(0xFF388E3C);
      case 'asking for directions':
        return const Color(0xFF1976D2);
      case 'essential conversations':
        return const Color(0xFF00695C);
      case 'at the airport':
        return const Color(0xFF455A64);
      case 'at the restaurant':
        return const Color(0xFFD84315);
      case 'at the hotel':
        return const Color(0xFF4E342E);
      case 'at the doctor\'s office':
        return const Color(0xFFC62828);
      case 'public transportation':
        return const Color(0xFF7B1FA2);
      case 'shopping for clothes':
        return const Color(0xFFC2185B);
      case 'at the gym':
        return const Color(0xFFEF6C00);
      case 'at the bank':
        return const Color(0xFF512DA8);
      case 'at the post office':
        return const Color(0xFF00838F);
      case 'at the pharmacy':
        return const Color(0xFF0097A7);
      case 'at the park':
        return const Color(0xFF689F38);
      case 'at the beach':
        return const Color(0xFF0288D1);
      case 'at the library':
        return const Color(0xFF3949AB);
      case 'at the cinema':
        return const Color(0xFF5E35B1);
      case 'at the hair salon':
        return const Color(0xFFAD1457);
      case 'custom lesson':
        return const Color(0xFF546E7A);
      default:
        final int hashCode = categoryName.toLowerCase().hashCode;
        return Color((hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(0.6);
    }
  }

  Future<void> _toggleCompletionStatus() async {
    final newCompletionStatus = !_isCompleted;

    // Show confirmation dialog
    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              newCompletionStatus ? 'Mark as Complete' : 'Mark as Incomplete'),
          content: Text(newCompletionStatus
              ? 'Are you sure you want to mark "${widget.audioFile.get('title')}" as completed?'
              : 'Are you sure you want to mark "${widget.audioFile.get('title')}" as incomplete?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor:
                    newCompletionStatus ? Colors.green : Colors.amber,
              ),
              child: Text(
                  newCompletionStatus ? 'Mark Complete' : 'Mark Incomplete'),
            ),
          ],
        );
      },
    );

    if (shouldUpdate == true) {
      setState(() {
        _isLoadingCompletion = true;
      });

      try {
        final parentDocId = widget.audioFile.reference.parent.parent!.id;

        await FirebaseFirestore.instance
            .collection('chatGPT_responses')
            .doc(parentDocId)
            .set({
          'completed': newCompletionStatus,
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() {
            _isCompleted = newCompletionStatus;
            _isLoadingCompletion = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newCompletionStatus
                    ? 'Lesson marked as completed!'
                    : 'Lesson marked as incomplete',
              ),
              backgroundColor:
                  newCompletionStatus ? Colors.green : Colors.amber,
            ),
          );

          // Reload the page to show correct data
          if (widget.onReload != null) {
            widget.onReload!();
          }
        }
      } catch (e) {
        print('Error updating completion status: $e');
        if (mounted) {
          setState(() {
            _isLoadingCompletion = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update lesson status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteLesson() async {
    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Lesson'),
          content: Text(
              'Are you sure you want to delete "${widget.audioFile.get('title')}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                _getAnalyticsManager()?.storeAction(
                    'lesson_delete_dialog_cancelled',
                    widget.audioFile.get('title'));
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _getAnalyticsManager()?.storeAction(
                    'lesson_delete_dialog_confirmed',
                    widget.audioFile.get('title'));
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      _getAnalyticsManager()?.storeAction(
          'lesson_deletion_initiated', widget.audioFile.get('title'));
      setState(() {
        _isDeleting = true;
      });

      try {
        // Delete the lesson document
        await widget.audioFile.reference.delete();

        // Also delete the parent document if this was the only script
        final parentRef = widget.audioFile.reference.parent.parent!;
        final scriptsSnapshot = await widget.audioFile.reference.parent.get();

        if (scriptsSnapshot.docs.isEmpty) {
          await parentRef.delete();
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lesson deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload the page
          if (widget.onReload != null) {
            widget.onReload!();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete lesson: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
        }
      }
    }
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lesson Options',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Complete/Incomplete option
                      // if (!_isLoadingCompletion)
                      //   ListTile(
                      //     leading: Icon(
                      //       _isCompleted ? Icons.radio_button_checked_rounded : Icons.check_circle_outline_rounded,
                      //       color: _isCompleted ? Colors.amber : Colors.green,
                      //     ),
                      //     title: Text(
                      //       _isCompleted ? 'Mark as Incomplete' : 'Mark as Complete',
                      //       style: TextStyle(
                      //         fontWeight: FontWeight.w500,
                      //         color: _isCompleted ? Colors.amber : Colors.green,
                      //       ),
                      //     ),
                      //     subtitle: Text(_isCompleted ? 'Remove completion status' : 'Mark this lesson as finished'),
                      //     onTap: () {
                      //       Navigator.pop(context);
                      //       _toggleCompletionStatus();
                      //     },
                      //   ),
                      if (!_isLoadingCompletion) const SizedBox(height: 8),
                      // Delete option
                      ListTile(
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red.withOpacity(0.8),
                        ),
                        title: Text(
                          'Delete Lesson',
                          style: TextStyle(
                            color: Colors.red.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text('This action cannot be undone'),
                        onTap: () {
                          _getAnalyticsManager()?.storeAction(
                              'lesson_card_delete_option_tapped',
                              widget.audioFile.get('title'));
                          Navigator.pop(context);
                          _deleteLesson();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final category = getCategory();
    final categoryColor = _getCategoryColor(category);

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: widget.showCategoryBadge ? 16 : 0,
          vertical: widget.isSmallScreen ? 8 : 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () async {
          final category = getCategory();
          _getAnalyticsManager()?.storeAction('lesson_card_tapped',
              '${widget.audioFile.get('title')}|$category');

          final manager =
              Provider.of<AudioPlayerManager>(context, listen: false);
          manager.playLesson(LessonData(
            documentID: widget.audioFile.reference.parent.parent!.id,
            dialogue: widget.audioFile.get('dialogue'),
            category: category,
            targetLanguage: widget.audioFile.get('target_language'),
            nativeLanguage: (widget.audioFile.data() as Map<String, dynamic>?)
                        ?.containsKey('native_language') ==
                    true
                ? widget.audioFile.get('native_language')
                : 'English (US)',
            languageLevel: widget.audioFile.get('language_level'),
            userID: FirebaseAuth.instance.currentUser!.uid,
            title: widget.audioFile.get('title'),
            scriptDocumentId: widget.audioFile.id,
            generating: false,
            wordsToRepeat: widget.audioFile.get('words_to_repeat'),
            numberOfTurns: 4,
          ));

          // We can't easily wait for result here since it's persistent.
          // Ideally LessonCard should listen to Firestore changes for completion status.
          // For now, we'll just let it be. The user can manually reload or we can rely on future stream updates.
        },
          borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.95 : 1.0)
            ..rotateZ(_isPressed ? -0.01 : 0.0),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Top right corner menu button
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _getAnalyticsManager()?.storeAction(
                          'lesson_card_options_menu_tapped',
                          widget.audioFile.get('title'));
                      _showOptionsMenu();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),

                // Right side play icon
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                      color: colorScheme.primary,
                    ),
                  ),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Creation date
                                  Text(
                        _getCreationDateText(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          letterSpacing: 0.2,
                              ),
                            ),
                      const SizedBox(height: 8),

                      // Title
                      Padding(
                        padding: const EdgeInsets.only(right: 50),
                        child: Text(
                          widget.audioFile.get('title'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                            height: 1.3,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bottom info row
                      Row(
                        children: [
                          // Duration
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                getEstimatedDuration(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Completion status indicator
                          if (!_isLoadingCompletion && _isCompleted)
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Colors.green.withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

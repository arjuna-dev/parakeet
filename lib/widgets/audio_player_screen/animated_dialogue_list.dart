import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/widgets/audio_player_screen/typing_animation_bubble.dart';

class AnimatedDialogueList extends StatefulWidget {
  final List<dynamic> dialogue;
  final String currentTrack;
  final List<dynamic> wordsToRepeat;
  final String documentID;
  final bool useStream;
  final Function? onAllDialogueDisplayed;
  final bool generating;

  const AnimatedDialogueList({
    Key? key,
    required this.dialogue,
    required this.currentTrack,
    required this.wordsToRepeat,
    this.documentID = '',
    this.useStream = false,
    this.onAllDialogueDisplayed,
    this.generating = false,
  }) : super(key: key);

  @override
  State<AnimatedDialogueList> createState() => _AnimatedDialogueListState();
}

class _AnimatedDialogueListState extends State<AnimatedDialogueList> {
  int _lastHighlightedIndex = -1;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<List<dynamic>> _dialogueNotifier = ValueNotifier<List<dynamic>>([]);
  Stream<QuerySnapshot>? _dialogueStream;

  // Track which messages have been animated
  final List<int> _animatedMessages = [];

  // Track which message is currently being animated
  int _currentlyAnimatingIndex = -1;

  // Control the visibility of messages
  final List<int> _visibleMessages = [];

  // Flag to track if we've already notified the parent
  bool _hasNotifiedAllDisplayed = false;

  @override
  void initState() {
    super.initState();
    _dialogueNotifier.value = List.from(widget.dialogue);

    if (widget.useStream && widget.documentID.isNotEmpty) {
      _dialogueStream = FirebaseFirestore.instance.collection('chatGPT_responses').doc(widget.documentID).collection('only_target_sentences').snapshots();
    } else if (widget.generating) {
      // If generating, show initial messages with animation
      _initializeVisibleMessages();
    } else {
      // If not generating, show all messages immediately without animation
      _showAllMessagesImmediately();
    }
  }

  void _initializeVisibleMessages() {
    try {
      if (!mounted) return;

      if (_dialogueNotifier.value.isNotEmpty) {
        // Find the first message with content
        int firstValidIndex = _findFirstValidMessageIndex(_dialogueNotifier.value);

        if (firstValidIndex >= 0) {
          // Check if the message is fully generated
          final dynamic dialogueItem = _dialogueNotifier.value[firstValidIndex];
          final String dialogueNative = dialogueItem["native_language"]?.toString() ?? "";

          // If native language is expected but missing, don't initialize yet
          if (dialogueNative.trim().isEmpty && dialogueItem.containsKey("native_language")) {
            print("First message has target text but native text is still generating, waiting...");
            // Try again after a delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _initializeVisibleMessages();
              }
            });
            return;
          }

          // Only initialize if we're not already animating something
          if (_currentlyAnimatingIndex == -1) {
            setState(() {
              try {
                _visibleMessages.add(firstValidIndex);
                _currentlyAnimatingIndex = firstValidIndex;
              } catch (e) {
                print("Error updating state in _initializeVisibleMessages: $e");
              }
            });

            // Schedule the next message to appear after the first one finishes
            // The animation completion callback will handle showing the next message
          } else {
            print("Already animating message $_currentlyAnimatingIndex, not initializing new messages");
          }
        } else {
          print("No valid messages found to initialize");
        }
      } else {
        print("Dialogue list is empty, nothing to initialize");
      }
    } catch (e) {
      print("Error in _initializeVisibleMessages: $e");
    }
  }

  // Helper method to find the first message with content
  int _findFirstValidMessageIndex(List<dynamic> dialogueData) {
    for (int i = 0; i < dialogueData.length; i++) {
      try {
        if (dialogueData[i] == null) continue;

        final String dialogueTarget = dialogueData[i]["target_language"]?.toString() ?? "";
        if (dialogueTarget.trim().isNotEmpty) {
          // Check if native language is expected and present
          if (dialogueData[i].containsKey("native_language")) {
            final String dialogueNative = dialogueData[i]["native_language"]?.toString() ?? "";
            if (dialogueNative.trim().isEmpty) {
              // Native language is expected but not yet generated
              print("Message $i has target text but native text is still generating");
              continue;
            }
          }

          return i;
        }
      } catch (e) {
        print("Error checking message $i: $e");
        continue;
      }
    }
    return -1;
  }

  void _animateNextMessage() {
    if (!mounted) return;

    try {
      final currentDialogue = _dialogueNotifier.value;
      _logDialogueState(currentDialogue, "Before animation");

      // If we're currently animating a message, don't start another one
      if (_currentlyAnimatingIndex != -1 && !_animatedMessages.contains(_currentlyAnimatingIndex)) {
        print("Already animating message $_currentlyAnimatingIndex, waiting for completion");
        return;
      }

      // Find the next message that should be shown
      int nextIndex = _findNextMessageToShow(currentDialogue);

      print("_animateNextMessage called, next index: $nextIndex, visible messages: $_visibleMessages");

      if (nextIndex >= 0 && nextIndex < currentDialogue.length) {
        try {
          // Check if this message has content and is fully generated
          final dynamic dialogueItem = currentDialogue[nextIndex];
          if (dialogueItem == null) {
            print("Message $nextIndex is null, skipping");
            setState(() {
              _visibleMessages.add(nextIndex); // Mark as visible so we don't try it again
              _animatedMessages.add(nextIndex); // Also mark as animated since there's nothing to animate
            });
            // Try the next message after a short delay
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _animateNextMessage();
              }
            });
            return;
          }

          final String dialogueTarget = dialogueItem["target_language"]?.toString() ?? "";
          final String dialogueNative = dialogueItem["native_language"]?.toString() ?? "";

          // Check if the message is fully generated (has both target and native text)
          bool isFullyGenerated = dialogueTarget.trim().isNotEmpty;

          // If native language is expected but missing or empty, consider it not fully generated
          if (isFullyGenerated && dialogueNative.trim().isEmpty && dialogueItem.containsKey("native_language")) {
            print("Message $nextIndex has target text but native text is still generating, waiting...");
            // Don't animate yet, wait for the next update
            return;
          }

          if (isFullyGenerated) {
            print("Showing message $nextIndex: $dialogueTarget");
            setState(() {
              _currentlyAnimatingIndex = nextIndex;
              _visibleMessages.add(nextIndex);
            });

            // Scroll to the new message
            _scrollToLatestMessage();
          } else {
            print("Skipping empty message $nextIndex");
            // Skip this message and try the next one
            setState(() {
              _visibleMessages.add(nextIndex); // Mark as visible so we don't try it again
              _animatedMessages.add(nextIndex); // Also mark as animated since there's nothing to animate
            });
            // Try the next message immediately
            _animateNextMessage();
          }
        } catch (e) {
          print("Error processing message $nextIndex: $e");
          // Skip this message and try the next one
          setState(() {
            _visibleMessages.add(nextIndex); // Mark as visible so we don't try it again
            _animatedMessages.add(nextIndex); // Also mark as animated to avoid getting stuck
          });
          // Try the next message after a short delay
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _animateNextMessage();
            }
          });
        }
      } else {
        print("No more messages to animate");

        // Reset the current animating index since we're done
        setState(() {
          _currentlyAnimatingIndex = -1;
        });

        // Check if we have displayed all valid messages
        if (currentDialogue.isNotEmpty && widget.onAllDialogueDisplayed != null && !_hasNotifiedAllDisplayed) {
          // Count valid messages
          int validMessageCount = 0;
          int visibleValidMessageCount = 0;

          for (int i = 0; i < currentDialogue.length; i++) {
            try {
              if (currentDialogue[i] == null) continue;
              final String dialogueTarget = currentDialogue[i]["target_language"]?.toString() ?? "";
              if (dialogueTarget.trim().isNotEmpty) {
                validMessageCount++;
                if (_visibleMessages.contains(i)) {
                  visibleValidMessageCount++;
                }
              }
            } catch (e) {
              print("Error counting valid messages in _animateNextMessage: $e");
            }
          }

          // If all valid messages are visible, notify
          if (validMessageCount > 0 && visibleValidMessageCount >= validMessageCount) {
            print("All dialogue messages have been displayed ($visibleValidMessageCount/$validMessageCount). Notifying parent from _animateNextMessage.");
            _hasNotifiedAllDisplayed = true;
            widget.onAllDialogueDisplayed?.call();
          } else {
            print("Not all dialogue messages are displayed yet: $visibleValidMessageCount/$validMessageCount in _animateNextMessage");
          }
        }
      }
    } catch (e) {
      print("Error in _animateNextMessage: $e");
    }
  }

  // Find the next message that should be shown in sequence
  int _findNextMessageToShow(List<dynamic> dialogueData) {
    // Start from the beginning and find the first message that's not yet visible
    for (int i = 0; i < dialogueData.length; i++) {
      try {
        if (dialogueData[i] == null) continue;

        final String dialogueTarget = dialogueData[i]["target_language"]?.toString() ?? "";
        final String dialogueNative = dialogueData[i]["native_language"]?.toString() ?? "";

        // Check if this message has content and is not yet visible
        if (dialogueTarget.trim().isNotEmpty && !_visibleMessages.contains(i)) {
          // If native language is expected but missing, consider it not fully generated
          if (dialogueNative.trim().isEmpty && dialogueData[i].containsKey("native_language")) {
            print("Message $i has target text but native text is still generating, skipping for now");
            continue;
          }

          return i;
        }
      } catch (e) {
        print("Error checking message $i in _findNextMessageToShow: $e");
        continue;
      }
    }

    // If we reach here, all messages have been shown
    // Check if we have any valid messages and notify if all are displayed
    if (dialogueData.isNotEmpty && widget.onAllDialogueDisplayed != null && !_hasNotifiedAllDisplayed) {
      // Count valid messages
      int validMessageCount = 0;
      for (int i = 0; i < dialogueData.length; i++) {
        try {
          if (dialogueData[i] == null) continue;
          final String dialogueTarget = dialogueData[i]["target_language"]?.toString() ?? "";
          if (dialogueTarget.trim().isNotEmpty) {
            validMessageCount++;
          }
        } catch (e) {
          print("Error counting valid messages: $e");
        }
      }

      // If we have valid messages and all are visible, notify
      if (validMessageCount > 0 && _visibleMessages.length >= validMessageCount) {
        print("All dialogue messages have been displayed (${_visibleMessages.length}/$validMessageCount). Notifying parent.");
        _hasNotifiedAllDisplayed = true;
        widget.onAllDialogueDisplayed?.call();
      } else {
        print("Not all dialogue messages are displayed yet: ${_visibleMessages.length}/$validMessageCount");
      }
    }

    return -1;
  }

  void _scrollToLatestMessage() {
    try {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (_scrollController.hasClients) {
            _scrollController
                .animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
                .catchError((error) {
              print("Error during scroll animation: $error");
            });
          }
        } catch (e) {
          print("Error in post-frame callback for scrolling: $e");
        }
      });
    } catch (e) {
      print("Error in _scrollToLatestMessage: $e");
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedDialogueList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update the last highlighted index if the current track is a dialogue
    List<String> parts = widget.currentTrack.split('_');
    if (parts.length >= 2 && parts[0] == 'dialogue') {
      int currentDialogueIndex = int.tryParse(parts[1]) ?? -1;
      if (currentDialogueIndex >= 0) {
        _lastHighlightedIndex = currentDialogueIndex;

        // Auto-scroll to the highlighted item
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && currentDialogueIndex > 0) {
            const itemHeight = 120.0; // Approximate height of each dialogue item
            final targetPosition = itemHeight * currentDialogueIndex;

            if (targetPosition > _scrollController.position.pixels + _scrollController.position.viewportDimension || targetPosition < _scrollController.position.pixels) {
              _scrollController.animateTo(
                targetPosition,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        });
      }
    }

    // Update dialogue only if it actually changed
    if (!_areDialoguesEqual(widget.dialogue, _dialogueNotifier.value)) {
      final oldLength = _dialogueNotifier.value.length;
      _dialogueNotifier.value = List.from(widget.dialogue);

      // Reset the notification flag when new dialogue data is received
      if (widget.dialogue.length != oldLength) {
        _hasNotifiedAllDisplayed = false;
      }

      // If not generating, show all messages immediately without animation
      if (!widget.generating) {
        _showAllMessagesImmediately();
      }
      // If generating and this is the first update with no visible messages yet
      else if (_visibleMessages.isEmpty && widget.dialogue.isNotEmpty) {
        _initializeVisibleMessages();
      }
      // If generating, already have visible messages, and new content was added
      else if (widget.generating && widget.dialogue.length > oldLength && !widget.useStream) {
        // Only trigger animation if we're not currently animating
        if (_currentlyAnimatingIndex == -1 || _animatedMessages.contains(_currentlyAnimatingIndex)) {
          _animateNextMessage();
        }
      }
    }
  }

  // Helper method to check if two dialogue lists are equal
  bool _areDialoguesEqual(List<dynamic> list1, List<dynamic> list2) {
    try {
      if (list1.length != list2.length) return false;

      for (int i = 0; i < list1.length; i++) {
        try {
          final dynamic targetLang1 = list1[i]['target_language'];
          final dynamic nativeLang1 = list1[i]['native_language'];
          final dynamic targetLang2 = list2[i]['target_language'];
          final dynamic nativeLang2 = list2[i]['native_language'];

          // Convert to strings for comparison to handle different types
          final String target1 = targetLang1?.toString() ?? "";
          final String native1 = nativeLang1?.toString() ?? "";
          final String target2 = targetLang2?.toString() ?? "";
          final String native2 = nativeLang2?.toString() ?? "";

          if (target1 != target2 || native1 != native2) {
            return false;
          }
        } catch (e) {
          print("Error comparing dialogue item $i: $e");
          return false; // Consider them different if we can't compare
        }
      }
      return true;
    } catch (e) {
      print("Error in _areDialoguesEqual: $e");
      return false; // Consider them different if there's an error
    }
  }

  Widget _buildDialogueItem(BuildContext context, dynamic dialogueItem, int index) {
    // Safety check for null or invalid dialogue item
    if (dialogueItem == null) {
      return const SizedBox.shrink();
    }

    final bool isVisible = _visibleMessages.contains(index);
    if (!isVisible) return const SizedBox.shrink();

    try {
      // Safely extract dialogue text with null checks
      final String dialogueTarget = dialogueItem["target_language"] as String? ?? "";
      final String dialogueNative = dialogueItem["native_language"] as String? ?? "";

      // Skip empty dialogue items
      if (dialogueTarget.trim().isEmpty) {
        return const SizedBox.shrink();
      }

      // Check if the message is fully generated
      bool isFullyGenerated = true;
      if (dialogueItem.containsKey("native_language") && dialogueNative.trim().isEmpty) {
        isFullyGenerated = false;
        print("Message $index is not fully generated yet (missing native language)");
        // If not fully generated, don't show it yet
        if (!_animatedMessages.contains(index)) {
          return const SizedBox.shrink();
        }
      }

      final bool shouldHighlight = index == _lastHighlightedIndex;
      final bool isEven = index.isEven;
      final bool isCurrentlyAnimating = index == _currentlyAnimatingIndex;
      final bool hasBeenAnimated = _animatedMessages.contains(index);

      // Calculate delay for staggered animation
      final Duration initialDelay = Duration(milliseconds: widget.useStream ? 500 : 0);

      // Alternate between user and non-user bubbles based on index
      final bool isUserMessage = isEven; // Even indices are user messages, odd are non-user

      // Single bubble with target language and native language as subtitle
      return TypingAnimationBubble(
        key: ValueKey('dialogue_$index'),
        text: dialogueTarget,
        subtitle: dialogueNative,
        isUser: isUserMessage,
        isHighlighted: shouldHighlight,
        wordsToHighlight: List<String>.from(widget.wordsToRepeat),
        // Only animate if we're generating content and the current message should be animated
        animate: widget.generating && isCurrentlyAnimating && !hasBeenAnimated && dialogueTarget.trim().isNotEmpty && isFullyGenerated,
        initialDelay: initialDelay,
        typingSpeed: const Duration(milliseconds: 30),
        onAnimationComplete: () {
          // Only handle animation completion if we're generating content
          if (widget.generating) {
            print("Animation completed for message $index");
            if (!_animatedMessages.contains(index)) {
              setState(() {
                _animatedMessages.add(index);
                // Reset the current animating index since this animation is complete
                if (_currentlyAnimatingIndex == index) {
                  _currentlyAnimatingIndex = -1;
                }
              });

              // Animate next message after this one is complete
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) {
                  print("Triggering next animation after message $index");
                  _animateNextMessage();
                }
              });
            }
          }
        },
      );
    } catch (e) {
      print("Error building dialogue item $index: $e");
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      // If streaming is enabled and we have a document ID, use StreamBuilder
      if (widget.useStream && widget.documentID.isNotEmpty && _dialogueStream != null) {
        return Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _dialogueStream,
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              try {
                // Handle error state with a more subtle approach
                if (snapshot.hasError) {
                  print("StreamBuilder error: ${snapshot.error}");
                  // Return the current dialogue list instead of an error message
                  return _buildDialogueListView(_dialogueNotifier.value);
                }

                // Show loading indicator only when we have no data at all
                if (snapshot.connectionState == ConnectionState.waiting && _dialogueNotifier.value.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Update dialogue data if new data is available
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  try {
                    final Map<String, dynamic> data = snapshot.data!.docs[0].data() as Map<String, dynamic>;
                    if (data.containsKey('dialogue')) {
                      final newDialogueData = data['dialogue'] as List<dynamic>;
                      if (!_areDialoguesEqual(newDialogueData, _dialogueNotifier.value)) {
                        // Store the old length before updating
                        final oldLength = _dialogueNotifier.value.length;
                        final bool wasEmpty = _dialogueNotifier.value.isEmpty;

                        // Update the dialogue data
                        _dialogueNotifier.value = List.from(newDialogueData);
                        _logDialogueState(newDialogueData, "Stream update");

                        // Reset the notification flag when new dialogue data is received
                        if (newDialogueData.length != oldLength) {
                          _hasNotifiedAllDisplayed = false;
                        }

                        // If not generating, show all messages immediately without animation
                        if (!widget.generating) {
                          _showAllMessagesImmediately();
                        }
                        // If generating and this is the first data we're receiving, initialize visible messages
                        else if (_visibleMessages.isEmpty && newDialogueData.isNotEmpty) {
                          int firstValidIndex = _findFirstValidMessageIndex(newDialogueData);
                          if (firstValidIndex >= 0) {
                            setState(() {
                              try {
                                _visibleMessages.add(firstValidIndex);
                                _currentlyAnimatingIndex = firstValidIndex;
                              } catch (e) {
                                print("Error updating state for first message: $e");
                              }
                            });

                            // Schedule the next message animation
                            Future.delayed(const Duration(milliseconds: 1500), () {
                              if (mounted) {
                                _animateNextMessage();
                              }
                            });
                          }
                        }
                        // If generating, already have visible messages, and new content was added
                        else if (widget.generating && newDialogueData.length > oldLength) {
                          print("New messages added: ${newDialogueData.length - oldLength}");

                          // Check if any of the new messages have content
                          bool hasNewContent = false;
                          bool allNewMessagesComplete = true;

                          for (int i = oldLength; i < newDialogueData.length; i++) {
                            try {
                              if (newDialogueData[i] == null) {
                                allNewMessagesComplete = false;
                                continue;
                              }

                              final String dialogueTarget = newDialogueData[i]["target_language"]?.toString() ?? "";
                              final String dialogueNative = newDialogueData[i]["native_language"]?.toString() ?? "";

                              // Check if this message has content
                              if (dialogueTarget.trim().isNotEmpty) {
                                hasNewContent = true;

                                // If native language is expected but missing, consider it incomplete
                                if (dialogueNative.trim().isEmpty && newDialogueData[i].containsKey("native_language")) {
                                  allNewMessagesComplete = false;
                                  print("Message $i has target text but native text is still generating");
                                }
                              }
                            } catch (e) {
                              print("Error checking new message $i: $e");
                              allNewMessagesComplete = false;
                            }
                          }

                          if (hasNewContent) {
                            // Only proceed with animation if all new messages are complete
                            if (allNewMessagesComplete) {
                              // Check if we're currently animating
                              if (_currentlyAnimatingIndex != -1 && !_animatedMessages.contains(_currentlyAnimatingIndex)) {
                                // We're still animating, so we'll let the onAnimationComplete callback handle the next message
                                print("Currently animating message $_currentlyAnimatingIndex, waiting for completion");
                              } else {
                                // We're not animating, so we can animate the next message now
                                print("Not currently animating, triggering next message animation");
                                // Add a small delay to ensure the UI is updated
                                Future.delayed(const Duration(milliseconds: 300), () {
                                  if (mounted) {
                                    _animateNextMessage();
                                  }
                                });
                              }
                            } else {
                              print("New messages added but some are still being generated, waiting for completion");
                            }
                          } else {
                            print("New messages added but they're all empty");
                          }
                        }
                        // If the content changed but length didn't increase
                        else if (!wasEmpty && newDialogueData.length == oldLength) {
                          // Check if there are messages that should be visible but aren't yet
                          int nextIndex = _findNextMessageToShow(newDialogueData);
                          if (nextIndex >= 0) {
                            print("Found message $nextIndex that should be shown");
                            if (!_animatedMessages.contains(_currentlyAnimatingIndex)) {
                              _animateNextMessage();
                            }
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print("Error processing snapshot data: $e");
                    // Continue with current data if there's an error
                  }
                }

                // Always return the current dialogue list
                return _buildDialogueListView(_dialogueNotifier.value);
              } catch (e) {
                print("Error in StreamBuilder: $e");
                // Return a fallback widget in case of error
                return const Center(child: Text("Error loading dialogue"));
              }
            },
          ),
        );
      } else {
        // Use the existing dialogue list if streaming is not enabled
        return Expanded(
          child: _buildDialogueListView(_dialogueNotifier.value),
        );
      }
    } catch (e) {
      print("Error in build method: $e");
      return const Expanded(
        child: Center(child: Text("Error building dialogue list")),
      );
    }
  }

  // Extract the ListView builder into a separate method to avoid duplication
  Widget _buildDialogueListView(List<dynamic> dialogueData) {
    try {
      return ListView.builder(
        key: const PageStorageKey('dialogue_list'),
        controller: _scrollController,
        itemCount: dialogueData.length,
        itemBuilder: (context, index) {
          try {
            if (index >= dialogueData.length) {
              return Container();
            }

            // Check for null data
            if (dialogueData[index] == null) {
              return const SizedBox.shrink();
            }

            return _buildDialogueItem(context, dialogueData[index], index);
          } catch (e) {
            print("Error building item at index $index: $e");
            return const SizedBox.shrink();
          }
        },
      );
    } catch (e) {
      print("Error in _buildDialogueListView: $e");
      return const Center(child: Text("Error displaying dialogue"));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dialogueNotifier.dispose();
    super.dispose();
  }

  // Debug method to log the current state of dialogue data
  void _logDialogueState(List<dynamic> dialogueData, String context) {
    try {
      print("=== Dialogue State ($context) ===");
      print("Total messages: ${dialogueData.length}");
      print("Visible messages: $_visibleMessages");
      print("Animated messages: $_animatedMessages");
      print("Currently animating: $_currentlyAnimatingIndex");

      for (int i = 0; i < dialogueData.length; i++) {
        try {
          final String target = dialogueData[i]["target_language"]?.toString() ?? "";
          final bool hasContent = target.trim().isNotEmpty;
          final bool isVisible = _visibleMessages.contains(i);
          final bool isAnimated = _animatedMessages.contains(i);

          print("Message $i: ${hasContent ? 'Has content' : 'Empty'}, ${isVisible ? 'Visible' : 'Hidden'}, ${isAnimated ? 'Animated' : 'Not animated'}");
        } catch (e) {
          print("Error logging message $i: $e");
        }
      }
      print("==============================");
    } catch (e) {
      print("Error in _logDialogueState: $e");
    }
  }

  // Helper method to show all messages immediately without animation
  void _showAllMessagesImmediately() {
    try {
      if (!mounted) return;

      final currentDialogue = _dialogueNotifier.value;
      if (currentDialogue.isEmpty) return;

      // Add all valid messages to visible and animated lists
      for (int i = 0; i < currentDialogue.length; i++) {
        try {
          if (currentDialogue[i] == null) continue;

          final String dialogueTarget = currentDialogue[i]["target_language"]?.toString() ?? "";
          if (dialogueTarget.trim().isNotEmpty) {
            _visibleMessages.add(i);
            _animatedMessages.add(i); // Mark as already animated
          }
        } catch (e) {
          print("Error processing message $i in _showAllMessagesImmediately: $e");
        }
      }

      // Notify parent that all messages are displayed
      if (widget.onAllDialogueDisplayed != null && !_hasNotifiedAllDisplayed && _visibleMessages.isNotEmpty) {
        _hasNotifiedAllDisplayed = true;
        widget.onAllDialogueDisplayed?.call();
      }
    } catch (e) {
      print("Error in _showAllMessagesImmediately: $e");
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

class TypingAnimationBubble extends StatefulWidget {
  final String text;
  final String? subtitle;
  final bool isUser;
  final bool isHighlighted;
  final List<String> wordsToHighlight;
  final bool animate;
  final VoidCallback? onAnimationComplete;
  final Duration typingSpeed;
  final Duration initialDelay;
  final Duration? breakdownStartTime;
  final Function(Duration)? onSeekToTime;

  const TypingAnimationBubble({
    Key? key,
    required this.text,
    this.subtitle,
    required this.isUser,
    this.isHighlighted = false,
    this.wordsToHighlight = const [],
    this.animate = true,
    this.onAnimationComplete,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.initialDelay = Duration.zero,
    this.breakdownStartTime,
    this.onSeekToTime,
  }) : super(key: key);

  @override
  State<TypingAnimationBubble> createState() => _TypingAnimationBubbleState();
}

class _TypingAnimationBubbleState extends State<TypingAnimationBubble> with TickerProviderStateMixin {
  String _displayedText = '';
  String _displayedSubtitle = '';
  bool _showTypingIndicator = false;
  bool _showSubtitle = false;
  Timer? _typingTimer;
  Timer? _subtitleTimer;
  Timer? _initialDelayTimer;
  late AnimationController _bounceController;
  late AnimationController _highlightController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _highlightAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _showTypingIndicator = true;
      _initialDelayTimer = Timer(widget.initialDelay, () {
        _startTypingAnimation();
      });
    } else {
      _displayedText = widget.text;
      _displayedSubtitle = widget.subtitle ?? '';
      _showSubtitle = widget.subtitle != null;
    }
  }

  @override
  void didUpdateWidget(covariant TypingAnimationBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start or stop highlight animation based on isHighlighted state
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _highlightController.repeat(reverse: true);
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _highlightController.stop();
      _highlightController.reset();
    }
  }

  void _startTypingAnimation() {
    if (mounted) {
      setState(() {
        _showTypingIndicator = false;
      });

      int charIndex = 0;
      _typingTimer = Timer.periodic(widget.typingSpeed, (timer) {
        if (charIndex < widget.text.length) {
          if (mounted) {
            setState(() {
              _displayedText = widget.text.substring(0, charIndex + 1);
            });
          }
          charIndex++;
        } else {
          timer.cancel();
          // Start showing subtitle after main text is complete
          if (widget.subtitle != null) {
            _startSubtitleAnimation();
          } else if (widget.onAnimationComplete != null) {
            widget.onAnimationComplete!();
          }
        }
      });
    }
  }

  void _startSubtitleAnimation() {
    if (mounted) {
      setState(() {
        _showSubtitle = true;
      });

      int charIndex = 0;
      // Use a slightly faster speed for subtitle animation
      final subtitleSpeed = Duration(milliseconds: (widget.typingSpeed.inMilliseconds * 0.7).round());

      _subtitleTimer = Timer.periodic(subtitleSpeed, (timer) {
        if (charIndex < (widget.subtitle?.length ?? 0)) {
          if (mounted) {
            setState(() {
              _displayedSubtitle = widget.subtitle!.substring(0, charIndex + 1);
            });
          }
          charIndex++;
        } else {
          timer.cancel();
          if (widget.onAnimationComplete != null) {
            widget.onAnimationComplete!();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _subtitleTimer?.cancel();
    _initialDelayTimer?.cancel();
    _bounceController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for other person (not shown for user)
          if (!widget.isUser) _buildAvatar(),

          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                widget.isHighlighted
                    ? AnimatedBuilder(
                        animation: _highlightAnimation,
                        builder: (context, child) {
                          return Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            margin: EdgeInsets.only(
                              left: widget.isUser ? 40 : 8,
                              right: widget.isUser ? 8 : 40,
                            ),
                            padding: const EdgeInsets.all(3), // Padding for border effect
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(21),
                                topRight: const Radius.circular(21),
                                bottomLeft: Radius.circular(widget.isUser ? 21 : 7),
                                bottomRight: Radius.circular(widget.isUser ? 7 : 21),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary.withOpacity(_highlightAnimation.value),
                                  colorScheme.secondary.withOpacity(_highlightAnimation.value),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(_highlightAnimation.value * 0.7),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: widget.isUser
                                    ? Color.lerp(const Color.fromARGB(255, 62, 59, 124), colorScheme.primaryContainer, _highlightAnimation.value * 0.3)
                                    : Color.lerp(const Color.fromARGB(255, 85, 52, 115), colorScheme.primaryContainer, _highlightAnimation.value * 0.3),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(widget.isUser ? 18 : 4),
                                  bottomRight: Radius.circular(widget.isUser ? 4 : 18),
                                ),
                              ),
                              child: _showTypingIndicator ? _buildTypingIndicator() : _buildTextContent(colorScheme),
                            ),
                          );
                        },
                      )
                    : Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        margin: EdgeInsets.only(
                          left: widget.isUser ? 40 : 8,
                          right: widget.isUser ? 8 : 40,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.isUser
                              ? const Color.fromARGB(255, 62, 59, 124) // User bubble color
                              : const Color.fromARGB(255, 85, 52, 115), // Other person bubble color
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(widget.isUser ? 18 : 4),
                            bottomRight: Radius.circular(widget.isUser ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(-1, 1),
                            ),
                          ],
                        ),
                        child: _showTypingIndicator ? _buildTypingIndicator() : _buildTextContent(colorScheme),
                      ),

                // Timestamp - show breakdown start time
                if (widget.breakdownStartTime != null && widget.breakdownStartTime! > Duration.zero)
                  Padding(
                    padding: EdgeInsets.only(
                      top: 6,
                      left: widget.isUser ? 0 : 12,
                      right: widget.isUser ? 12 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        if (widget.onSeekToTime != null) {
                          widget.onSeekToTime!(widget.breakdownStartTime!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.skip_next_rounded,
                              size: 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Jump to: ${_formatDuration(widget.breakdownStartTime!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Avatar for user (not shown for other person)
          if (widget.isUser) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isUser ? const Color.fromARGB(255, 62, 59, 124) : const Color.fromARGB(255, 85, 52, 115),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.isUser ? '👤' : '🗣️',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        );
      },
    );
  }

  Widget _buildDot(int index) {
    // Stagger the animation for each dot
    final delay = index * 0.2;
    final animationValue = (_bounceController.value - delay).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(0, -_bounceAnimation.value * animationValue),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildTextContent(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main text (target language)
        widget.wordsToHighlight.isEmpty
            ? Text(
                _displayedText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: widget.isHighlighted ? FontWeight.bold : FontWeight.normal,
                ),
              )
            : Wrap(
                children: _displayedText.split(' ').map<Widget>((word) {
                  final cleanWord = word.replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '').toLowerCase();
                  final match = widget.wordsToHighlight.contains(cleanWord);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.0),
                    margin: EdgeInsets.zero,
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: 16,
                        color: match ? colorScheme.tertiary : Colors.white,
                        fontWeight: widget.isHighlighted || match ? FontWeight.bold : FontWeight.normal,
                        decoration: match ? TextDecoration.underline : TextDecoration.none,
                        decorationThickness: match ? 1.0 : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

        // Subtitle (native language)
        if (_showSubtitle && widget.subtitle != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Divider(
              color: Colors.white24,
              height: 1,
              thickness: 0.5,
            ),
          ),
          Text(
            _displayedSubtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

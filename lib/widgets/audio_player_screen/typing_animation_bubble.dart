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
  }) : super(key: key);

  @override
  State<TypingAnimationBubble> createState() => _TypingAnimationBubbleState();
}

class _TypingAnimationBubbleState extends State<TypingAnimationBubble> with SingleTickerProviderStateMixin {
  String _displayedText = '';
  String _displayedSubtitle = '';
  bool _showTypingIndicator = false;
  bool _showSubtitle = false;
  Timer? _typingTimer;
  Timer? _subtitleTimer;
  Timer? _initialDelayTimer;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  final DateTime _timestamp = DateTime.now();

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
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
                Container(
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
                        color: widget.isHighlighted ? colorScheme.onPrimaryContainer.withOpacity(0.5) : colorScheme.shadow.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(-1, 1),
                      ),
                    ],
                  ),
                  child: _showTypingIndicator ? _buildTypingIndicator() : _buildTextContent(colorScheme),
                ),

                // Timestamp
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: widget.isUser ? 0 : 12,
                    right: widget.isUser ? 12 : 0,
                  ),
                  child: Text(
                    _formatTime(_timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
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

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

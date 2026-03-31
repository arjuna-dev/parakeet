import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parakeet/services/audio_player_service.dart';

class AnimatedGrammarSectionList extends StatefulWidget {
  final List<dynamic> segments;
  final String currentTrack;
  final AudioPlayerService audioPlayerService;
  final String documentID;
  final int part1SegmentCount;
  final bool useStream;
  final bool generating;
  final VoidCallback? onAllSectionsDisplayed;

  const AnimatedGrammarSectionList({
    super.key,
    required this.segments,
    required this.currentTrack,
    required this.audioPlayerService,
    required this.documentID,
    this.part1SegmentCount = 0,
    this.useStream = false,
    this.generating = false,
    this.onAllSectionsDisplayed,
  });

  @override
  State<AnimatedGrammarSectionList> createState() =>
      _AnimatedGrammarSectionListState();
}

class _AnimatedGrammarSectionListState
    extends State<AnimatedGrammarSectionList> {
  static const double _estimatedLineExtent = 108.0;
  static const double _minScrollDelta = 36.0;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<List<dynamic>> _segmentsNotifier =
      ValueNotifier<List<dynamic>>([]);
  Stream<QuerySnapshot>? _segmentsStream;
  StreamSubscription<Duration>? _positionSubscription;

  int _highlightedIndex = -1;
  bool _hasNotifiedSectionsDisplayed = false;

  @override
  void initState() {
    super.initState();
    _segmentsNotifier.value = List<dynamic>.from(widget.segments);
    if (widget.useStream && widget.documentID.isNotEmpty) {
      _segmentsStream = FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(widget.documentID)
          .collection('only_target_sentences')
          .snapshots();
    }
    _positionSubscription =
        widget.audioPlayerService.player.positionStream.listen((_) {
      if (!mounted) return;
      _updateHighlightedIndex();
    });
    _updateHighlightedIndex();
    _scheduleSectionsDisplayedIfReady();
  }

  @override
  void didUpdateWidget(covariant AnimatedGrammarSectionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areSegmentsEqual(widget.segments, _segmentsNotifier.value)) {
      _segmentsNotifier.value = List<dynamic>.from(widget.segments);
    }
    _updateHighlightedIndex();
    _scheduleSectionsDisplayedIfReady();
  }

  bool _areSegmentsEqual(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final left = a[i] as Map?;
      final right = b[i] as Map?;
      if (left?['native_language'] != right?['native_language'] ||
          left?['target_language'] != right?['target_language'] ||
          left?['title'] != right?['title'] ||
          left?['text'] != right?['text'] ||
          left?['speaker'] != right?['speaker']) {
        return false;
      }
    }
    return true;
  }

  int _utf8Size(String text) => utf8.encode(text).length;

  List<List<int>> _buildBatchRanges(List<dynamic> segments, int startOffset) {
    const maxBytes = 3200;
    const maxTurns = 12;
    final ranges = <List<int>>[];
    var current = <int>[];
    var currentBytes = 0;

    for (int localIndex = 0; localIndex < segments.length; localIndex++) {
      final absoluteIndex = startOffset + localIndex;
      final item = segments[localIndex] as Map<String, dynamic>;
      final speaker =
          (item['speaker'] ?? '').toString() == 'speaker_1' ? 'Speaker1' : 'Speaker2';
      final text = _segmentText(item);
      if (text.isEmpty) continue;
      final turnBytes = _utf8Size(text) + _utf8Size(speaker) + 16;

      if (current.isNotEmpty &&
          (current.length >= maxTurns || currentBytes + turnBytes > maxBytes)) {
        ranges.add(List<int>.from(current));
        current = <int>[];
        currentBytes = 0;
      }

      current.add(absoluteIndex);
      currentBytes += turnBytes;
    }

    if (current.isNotEmpty) {
      ranges.add(List<int>.from(current));
    }

    return ranges;
  }

  List<List<int>> _allBatchRanges(List<dynamic> segments) {
    final safeCount = widget.part1SegmentCount.clamp(0, segments.length);
    final part1 = segments.take(safeCount).toList();
    final part2 = segments.skip(safeCount).toList();

    return <List<int>>[
      ..._buildBatchRanges(part1, 0),
      ..._buildBatchRanges(part2, safeCount),
    ];
  }

  String _normalizedTrackKey(String rawTrack) {
    final trimmed = rawTrack.trim();
    if (trimmed.isEmpty) return '';
    final withoutQuery = trimmed.split('?').first;
    return withoutQuery.endsWith('.mp3')
        ? withoutQuery.substring(0, withoutQuery.length - 4)
        : withoutQuery;
  }

  int _highlightedIndexForCurrentTrack(List<dynamic> segments) {
    final currentTrack = _normalizedTrackKey(widget.currentTrack);
    if (currentTrack.isEmpty) {
      return -1;
    }

    if (currentTrack == 'title') {
      return segments.isEmpty ? -1 : 0;
    }

    if (currentTrack.startsWith('segments_')) {
      final parts = currentTrack.split('_');
      return parts.length >= 2 ? (int.tryParse(parts[1]) ?? -1) : -1;
    }

    final batchMatch = RegExp(r'^grammar_part_(\d+)_batch_(\d+)$')
        .firstMatch(currentTrack);
    if (batchMatch == null) {
      return -1;
    }

    final partNumber = int.tryParse(batchMatch.group(1) ?? '') ?? 0;
    final batchIndex = int.tryParse(batchMatch.group(2) ?? '') ?? 0;
    final ranges = _allBatchRanges(segments);

    final globalBatchIndex = partNumber == 1
        ? batchIndex
        : _buildBatchRanges(
                segments.take(widget.part1SegmentCount.clamp(0, segments.length)).toList(),
                0)
            .length +
            batchIndex;

    if (globalBatchIndex < 0 || globalBatchIndex >= ranges.length) {
      return -1;
    }

    final range = ranges[globalBatchIndex];
    if (range.isEmpty) {
      return -1;
    }

    final trackDuration = widget.audioPlayerService.player.duration;
    final position = widget.audioPlayerService.player.position;
    if (trackDuration == null || trackDuration <= Duration.zero) {
      return range.first;
    }

    final totalWeight = range.fold<int>(
      0,
      (sum, index) => sum + _segmentWeight(segments[index] as Map<String, dynamic>),
    );
    if (totalWeight <= 0) {
      return range.first;
    }

    final progress =
        (position.inMilliseconds / trackDuration.inMilliseconds).clamp(0.0, 0.999);
    final targetWeight = totalWeight * progress;
    var cumulative = 0;

    for (final index in range) {
      cumulative += _segmentWeight(segments[index] as Map<String, dynamic>);
      if (targetWeight < cumulative) {
        return index;
      }
    }

    return range.last;
  }

  int _segmentWeight(Map<String, dynamic> segment) {
    final text = _segmentText(segment);
    return text.isEmpty ? 1 : text.length.clamp(1, 200);
  }

  String _segmentText(Map<String, dynamic> segment) {
    final speakerKey = (segment['speaker'] ?? '').toString();
    final text = (segment['text'] ?? '').toString().replaceAll('||', '').trim();
    final native = (segment['native_language'] ?? '')
        .toString()
        .replaceAll('||', '')
        .trim();
    final target = (segment['target_language'] ?? '')
        .toString()
        .replaceAll('||', '')
        .trim();

    if (speakerKey == 'speaker_1') {
      if (text.isNotEmpty) return text;
      if (native.isNotEmpty) return native;
      return target;
    }

    if (speakerKey == 'speaker_2') {
      if (text.isNotEmpty) return text;
      if (target.isNotEmpty) return target;
      return native;
    }

    if (text.isNotEmpty) return text;
    if (native.isNotEmpty) return native;
    return target;
  }

  void _updateHighlightedIndex() {
    final sections = _segmentsNotifier.value;
    if (sections.isEmpty) return;
    final newIndex = _highlightedIndexForCurrentTrack(sections);
    final effectiveIndex = newIndex < 0 ? 0 : newIndex;
    if (effectiveIndex == _highlightedIndex) return;
    setState(() {
      _highlightedIndex = effectiveIndex;
    });
    _scrollToHighlightedIndex();
  }

  void _scrollToHighlightedIndex() {
    if (!_scrollController.hasClients || _highlightedIndex < 0) return;
    final rawTargetOffset = (_highlightedIndex * _estimatedLineExtent) -
        (_scrollController.position.viewportDimension * 0.35);
    final targetOffset = rawTargetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    final currentOffset = _scrollController.offset;
    if ((targetOffset - currentOffset).abs() < _minScrollDelta) {
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  Widget _buildLyricLine(
      BuildContext context, Map<String, dynamic> segment, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveHighlight = _highlightedIndex < 0 ? 0 : _highlightedIndex;
    final distance = (effectiveHighlight - index).abs();
    final isActive = index == effectiveHighlight;
    final text = _segmentText(segment);
    final speakerKey = (segment['speaker'] ?? '').toString();
    final isTargetSpeaker = speakerKey == 'speaker_2';
    final speakerLabel = speakerKey == 'speaker_2' ? 'Target' : 'Narrator';

    final Color textColor;
    if (isActive) {
      textColor = isTargetSpeaker
          ? colorScheme.tertiaryFixed
          : Colors.white;
    } else if (distance == 1) {
      textColor = isTargetSpeaker
          ? colorScheme.tertiaryFixed.withOpacity(0.8)
          : Colors.white.withOpacity(0.92);
    } else if (distance == 2) {
      textColor = isTargetSpeaker
          ? colorScheme.tertiaryFixed.withOpacity(0.68)
          : Colors.white.withOpacity(0.82);
    } else {
      textColor = isTargetSpeaker
          ? colorScheme.tertiaryFixed.withOpacity(0.58)
          : Colors.white.withOpacity(0.74);
    }

    final double fontSize = isActive
        ? (isTargetSpeaker ? 28 : 21)
        : distance == 1
            ? (isTargetSpeaker ? 20 : 17)
            : (isTargetSpeaker ? 18 : 15);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                speakerLabel,
              style: TextStyle(
                color: textColor.withOpacity(isActive ? 0.9 : 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: isTargetSpeaker
                      ? (isActive ? FontWeight.w700 : FontWeight.w600)
                      : (isActive ? FontWeight.w800 : FontWeight.w700),
                  height: 1.2,
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleSectionsDisplayedIfReady() {
    if (_hasNotifiedSectionsDisplayed) return;
    if (widget.generating) return;
    if (_segmentsNotifier.value.isEmpty) return;
    _hasNotifiedSectionsDisplayed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAllSectionsDisplayed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final listView = ValueListenableBuilder<List<dynamic>>(
      valueListenable: _segmentsNotifier,
      builder: (context, sections, child) {
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 140),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final segment = sections[index] as Map<String, dynamic>;
            return _buildLyricLine(context, segment, index);
          },
        );
      },
    );

    if (_segmentsStream != null) {
      return StreamBuilder<QuerySnapshot>(
        stream: _segmentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final data =
                snapshot.data!.docs.first.data() as Map<String, dynamic>;
            if (data['segments'] is List &&
                !_areSegmentsEqual(data['segments'] as List<dynamic>,
                    _segmentsNotifier.value)) {
              _segmentsNotifier.value =
                  List<dynamic>.from(data['segments'] as List<dynamic>);
              _scheduleSectionsDisplayedIfReady();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _updateHighlightedIndex();
                }
              });
            }
          }
          return listView;
        },
      );
    }

    return listView;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    _segmentsNotifier.dispose();
    super.dispose();
  }
}

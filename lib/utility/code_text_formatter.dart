import 'package:flutter/material.dart';

class CodeTextFormatter {
  static List<InlineSpan> buildSpans({
    required String text,
    required TextStyle baseStyle,
    Color? hashtagColor,
    Color? mentionColor,
    TextStyle? codeStyle,
  }) {
    if (text.isEmpty) {
      return <InlineSpan>[];
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp blockRegex = RegExp(r"```([\s\S]*?)```");
    int index = 0;

    final Iterable<RegExpMatch> matches = blockRegex.allMatches(text);
    if (matches.isEmpty) {
      spans.addAll(
        _buildInlineAndNormalSpans(
          text,
          baseStyle,
          hashtagColor: hashtagColor,
          mentionColor: mentionColor,
          codeStyle: codeStyle,
        ),
      );
      return spans;
    }

    for (final RegExpMatch match in matches) {
      if (match.start > index) {
        spans.addAll(
          _buildInlineAndNormalSpans(
            text.substring(index, match.start),
            baseStyle,
            hashtagColor: hashtagColor,
            mentionColor: mentionColor,
            codeStyle: codeStyle,
          ),
        );
      }

      final String codeText = match.group(1) ?? '';
      if (codeText.isNotEmpty) {
        final TextStyle effectiveCodeStyle = (codeStyle ?? baseStyle).copyWith(
          fontFamily: (codeStyle ?? baseStyle).fontFamily ?? 'monospace',
        );
        spans.add(TextSpan(text: codeText, style: effectiveCodeStyle));
      }

      index = match.end;
    }

    if (index < text.length) {
      spans.addAll(
        _buildInlineAndNormalSpans(
          text.substring(index),
          baseStyle,
          hashtagColor: hashtagColor,
          mentionColor: mentionColor,
          codeStyle: codeStyle,
        ),
      );
    }

    return spans;
  }

  static List<InlineSpan> _buildInlineAndNormalSpans(
    String text,
    TextStyle baseStyle, {
    Color? hashtagColor,
    Color? mentionColor,
    TextStyle? codeStyle,
  }) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp inlineRegex = RegExp(r"`([^`]+)`");
    int index = 0;

    for (final RegExpMatch match in inlineRegex.allMatches(text)) {
      if (match.start > index) {
        spans.addAll(
          _buildHashtagMentionSpans(
            text.substring(index, match.start),
            baseStyle,
            hashtagColor: hashtagColor,
            mentionColor: mentionColor,
          ),
        );
      }

      final String codeText = match.group(1) ?? '';
      if (codeText.isNotEmpty) {
        final TextStyle effectiveCodeStyle = (codeStyle ?? baseStyle).copyWith(
          fontFamily: (codeStyle ?? baseStyle).fontFamily ?? 'monospace',
        );
        spans.add(TextSpan(text: codeText, style: effectiveCodeStyle));
      }

      index = match.end;
    }

    if (index < text.length) {
      spans.addAll(
        _buildHashtagMentionSpans(
          text.substring(index),
          baseStyle,
          hashtagColor: hashtagColor,
          mentionColor: mentionColor,
        ),
      );
    }

    return spans;
  }

  static List<InlineSpan> _buildHashtagMentionSpans(
    String text,
    TextStyle baseStyle, {
    Color? hashtagColor,
    Color? mentionColor,
  }) {
    final List<InlineSpan> spans = <InlineSpan>[];
    if (hashtagColor == null && mentionColor == null) {
      spans.add(TextSpan(text: text, style: baseStyle));
      return spans;
    }

    final RegExp pattern = RegExp(r'(#[\w]+|@(?:[A-Za-z]+(?:\s+[A-Za-z]+)?))');
    int index = 0;

    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(
          TextSpan(text: text.substring(index, match.start), style: baseStyle),
        );
      }

      final String token = match.group(0) ?? '';
      TextStyle style = baseStyle;
      if (token.startsWith('#') && hashtagColor != null) {
        style = baseStyle.copyWith(color: hashtagColor);
      } else if (token.startsWith('@') && mentionColor != null) {
        style = baseStyle.copyWith(color: mentionColor);
      }

      spans.add(TextSpan(text: token, style: style));
      index = match.end;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: baseStyle));
    }

    return spans;
  }
}

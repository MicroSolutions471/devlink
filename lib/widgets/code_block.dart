// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeBlock extends StatefulWidget {
  final String code;
  final EdgeInsetsGeometry padding;
  final String? language;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const CodeBlock({
    super.key,
    required this.code,
    this.padding = const EdgeInsets.all(8),
    this.language,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _isDark = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _isDark = Theme.of(context).brightness == Brightness.dark;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // If user toggled to dark mode, ignore custom colors and use dark theme
    // Otherwise, use custom colors if provided, or default based on initial theme
    final bg = _isDark
        ? const Color(0xFF111827)
        : (widget.backgroundColor ??
              scheme.surfaceContainerHighest.withOpacity(0.3));
    final border = _isDark
        ? const Color(0xFF374151)
        : (widget.borderColor ?? scheme.outlineVariant);
    final baseTextColor = _isDark
        ? const Color(0xFFE5E7EB)
        : (widget.textColor ?? scheme.onSurface);

    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.4,
      color: baseTextColor,
    );

    final languageLabel = _resolveLanguageLabel(widget.language, widget.code);

    return Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withOpacity(0.7), width: 0.8),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText.rich(
                  TextSpan(
                    children: _buildHighlightedSpans(widget.code, baseStyle),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InkWell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: Icon(
                          _isDark ? Icons.light_mode : Icons.dark_mode,
                          size: 18,
                          color: baseTextColor,
                        ),
                      ),
                    ),

                    onTap: () {
                      setState(() => _isDark = !_isDark);
                    },
                  ),
                  InkWell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: Icon(
                          FluentSystemIcons.ic_fluent_copy_regular,
                          size: 18,
                          color: baseTextColor,
                        ),
                      ),
                    ),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: widget.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          if (languageLabel != null && languageLabel.isNotEmpty)
            Positioned(
              right: 4,
              bottom: 2,
              child: Text(
                languageLabel,
                style: baseStyle.copyWith(
                  fontSize: 10,
                  color: baseTextColor.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _resolveLanguageLabel(String? explicit, String code) {
    final raw = explicit?.trim();
    if (raw != null && raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      switch (lower) {
        case 'cpp':
        case 'c++':
          return 'C++';
        case 'c':
          return 'C';
        case 'cs':
        case 'c#':
        case 'csharp':
          return 'C#';
        case 'java':
          return 'Java';
        case 'py':
        case 'python':
          return 'Python';
        case 'js':
        case 'javascript':
          return 'JavaScript';
        case 'ts':
        case 'typescript':
          return 'TypeScript';
        case 'php':
          return 'PHP';
        case 'dart':
          return 'Dart';
        case 'flutter':
          return 'Flutter';
        case 'kt':
        case 'kotlin':
          return 'Kotlin';
        case 'html':
          return 'HTML';
        case 'css':
          return 'CSS';
        default:
          return raw;
      }
    }
    // No explicit language header provided – try a very simple heuristic guess.
    final snippet = code.toLowerCase();

    if (snippet.contains('using system;') ||
        (snippet.contains('namespace ') && snippet.contains('class '))) {
      return 'C#';
    }
    if (snippet.contains('#include') || snippet.contains('std::')) {
      return 'C++';
    }
    if (snippet.contains('public static void main(') ||
        snippet.contains('system.out.println')) {
      return 'Java';
    }
    if (snippet.contains('def ') &&
        snippet.contains(':') &&
        snippet.contains('print(')) {
      return 'Python';
    }
    if (snippet.contains('<?php') || snippet.contains('echo ')) {
      return 'PHP';
    }
    if (snippet.contains('console.log(') ||
        snippet.contains('function ') ||
        snippet.contains('=>') && snippet.contains('=> {')) {
      return 'JavaScript';
    }
    if (snippet.contains('import ') && snippet.contains('dart:')) {
      return 'Dart';
    }
    if (snippet.contains('@override') && snippet.contains('widget build(')) {
      return 'Flutter';
    }
    if (snippet.contains('fun main(') || snippet.contains('println(')) {
      return 'Kotlin';
    }
    if (snippet.contains('<html') ||
        snippet.contains('<div') ||
        snippet.contains('<body')) {
      return 'HTML';
    }
    if (snippet.contains('{') &&
        (snippet.contains('color:') || snippet.contains('background:')) &&
        !snippet.contains('class ')) {
      return 'CSS';
    }

    return null;
  }

  List<InlineSpan> _buildHighlightedSpans(String code, TextStyle baseStyle) {
    final isDark = _isDark;

    final commentStyle = baseStyle.copyWith(
      color: isDark ? const Color(0xFF6EE7B7) : Colors.green.shade700,
    );
    final stringStyle = baseStyle.copyWith(
      color: isDark ? const Color(0xFFFBBF24) : Colors.orange.shade700,
    );
    final keywordStyle = baseStyle.copyWith(
      color: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade700,
      fontWeight: FontWeight.w600,
    );
    final numberStyle = baseStyle.copyWith(
      color: isDark ? const Color(0xFFF472B6) : Colors.purple.shade700,
    );
    final directiveStyle = baseStyle.copyWith(
      color: isDark ? const Color(0xFFF97316) : Colors.deepOrange,
    );

    const keywords = <String>{
      // C / C++ / C# / Java / Kotlin / Dart core types
      'int',
      'short',
      'long',
      'float',
      'double',
      'char',
      'void',
      'bool',
      'boolean',
      'String',
      'List',
      'Map',
      'Set',

      // Declarations / classes / interfaces
      'class',
      'struct',
      'enum',
      'interface',
      'mixin',

      // Control flow
      'if',
      'else',
      'elif',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'break',
      'continue',
      'return',
      'yield',

      // Visibility / modifiers
      'public',
      'private',
      'protected',
      'internal',
      'static',
      'const',
      'final',
      'abstract',
      'override',
      'extends',
      'implements',
      'with',
      'sealed',

      // Variables and values
      'var',
      'late',
      'dynamic',
      'required',

      // Namespaces / modules / imports
      'package',
      'using',
      'namespace',
      'include',
      'import',
      'export',
      'from',
      'as',

      // Exceptions
      'try',
      'catch',
      'finally',
      'throw',
      'throws',
      'except',

      // Functions / async
      'def',
      'lambda',
      'function',
      'async',
      'await',

      // Common identifiers / literals
      'this',
      'super',
      'new',
      'delete',
      'true',
      'false',
      'null',
      'None',

      // PHP / JS / web-ish
      'echo',
      'typeof',
      'instanceof',
    };

    final lines = code.split('\n');
    final spans = <InlineSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      // Preprocessor directives like #include
      if (trimmed.startsWith('#')) {
        spans.add(TextSpan(text: line, style: directiveStyle));
      } else if (trimmed.startsWith('//')) {
        // Single-line comment
        spans.add(TextSpan(text: line, style: commentStyle));
      } else {
        // Basic token-based highlighting for the rest
        const tokenPattern = r'''(\w+|\s+|"[^"]*"|'[^']*'|[^\w\s]+)''';
        final tokens = RegExp(tokenPattern).allMatches(line);
        for (final match in tokens) {
          final token = match.group(0) ?? '';
          TextStyle style = baseStyle;

          if (token.trim().isEmpty) {
            // whitespace
            style = baseStyle;
          } else if (token.startsWith('"') &&
              token.endsWith('"') &&
              token.length >= 2) {
            style = stringStyle;
          } else if (token.startsWith("'") &&
              token.endsWith("'") &&
              token.length >= 2) {
            style = stringStyle;
          } else if (RegExp(r'^\d').hasMatch(token)) {
            style = numberStyle;
          } else if (keywords.contains(token)) {
            style = keywordStyle;
          }

          spans.add(TextSpan(text: token, style: style));
        }
      }

      if (i != lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return spans;
  }
}

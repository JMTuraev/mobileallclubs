import 'package:flutter/material.dart';

class FoundationPage extends StatelessWidget {
  const FoundationPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(subtitle, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

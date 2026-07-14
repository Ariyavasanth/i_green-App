import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SectionPage extends StatelessWidget {
  const SectionPage({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.pageTitle)),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: Text('New $title'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Card(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 42,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text('$title content', style: AppTextStyles.heading),
                  const SizedBox(height: 4),
                  const Text(
                    'This section is ready for its feature content.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

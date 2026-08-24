import 'dart:io';

import 'package:flutter/material.dart';

import '../../files/widgets/file_previews.dart';

/// Standard layout for tool options: input chips + before preview at top,
/// form controls in the middle, Run button pinned at the bottom.
class OptionsShell extends StatelessWidget {
  const OptionsShell({
    super.key,
    required this.inputs,
    required this.children,
    required this.onRun,
    this.previewHeight = 140,
  });

  final List<String> inputs;
  final List<Widget> children;
  final ValueChanged<Map<String, dynamic>> onRun;
  final double previewHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InputChips(inputs: inputs),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: previewHeight,
                  width: double.infinity,
                  color: scheme.surfaceContainerHighest,
                  child: FileThumbnail(path: inputs.first, width: 400),
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run'),
                onPressed: () => onRun(const {}),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputChips extends StatelessWidget {
  const _InputChips({required this.inputs});

  final List<String> inputs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in inputs.take(6))
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(p.split(Platform.pathSeparator).last, style: const TextStyle(fontSize: 12)),
          ),
        if (inputs.length > 6)
          Chip(label: Text('+${inputs.length - 6}'), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class OptionSlider extends StatelessWidget {
  const OptionSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final double value;
  final double min, max;
  final ValueChanged<double> onChanged;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text('${value.toStringAsFixed(0)}$suffix', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class OptionSegmented<T> extends StatelessWidget {
  const OptionSegmented({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: value == entry.key,
                  onSelected: (_) => onChanged(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

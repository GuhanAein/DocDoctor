
import 'package:flutter/material.dart';

import '../../../core/models/tool.dart';
import '../../files/widgets/file_previews.dart';

enum PageSelectMode { select, reorder }

class PdfPageSelector extends StatefulWidget {
  const PdfPageSelector({
    super.key,
    required this.tool,
    required this.inputPath,
    required this.mode,
    required this.onRun,
    this.title,
  });

  final ToolDefinition tool;
  final String inputPath;
  final PageSelectMode mode;
  final ValueChanged<List<int>> onRun;
  final String? title;

  @override
  State<PdfPageSelector> createState() => _PdfPageSelectorState();
}

class _PdfPageSelectorState extends State<PdfPageSelector> {
  int? _pageCount;
  final Set<int> _selected = {};
  late List<int> _order;

  @override
  void initState() {
    super.initState();
    pdfPageCount(widget.inputPath).then((count) {
      if (mounted) {
        setState(() {
          _pageCount = count;
          _order = List.generate(count ?? 0, (i) => i + 1);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _pageCount;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            widget.title ??
                (widget.mode == PageSelectMode.reorder
                    ? 'Drag pages into the new order'
                    : 'Tap pages to select them'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: count == null
              ? const Center(child: CircularProgressIndicator())
              : widget.mode == PageSelectMode.reorder
                  ? _ReorderGrid(
                      path: widget.inputPath,
                      count: count,
                      order: _order,
                      onReorder: (newOrder) => setState(() => _order = newOrder),
                    )
                  : _SelectGrid(
                      path: widget.inputPath,
                      count: count,
                      selected: _selected,
                      onToggle: (p) => setState(() {
                        if (_selected.contains(p)) {
                          _selected.remove(p);
                        } else {
                          _selected.add(p);
                        }
                      }),
                    ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(widget.mode == PageSelectMode.reorder
                    ? 'Run (${_order.length} pages)'
                    : 'Run (${_selected.length} selected)'),
                onPressed: () => widget.onRun(
                  widget.mode == PageSelectMode.reorder
                      ? List.of(_order)
                      : (_selected.toList()..sort()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectGrid extends StatelessWidget {
  const _SelectGrid({
    required this.path,
    required this.count,
    required this.selected,
    required this.onToggle,
  });

  final String path;
  final int count;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final page = i + 1;
        final isSel = selected.contains(page);
        return InkWell(
          onTap: () => onToggle(page),
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: PdfThumbnail(path: path, page: page, width: 220),
                ),
              ),
              if (isSel)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                  ),
                ),
              Positioned(
                left: 4,
                top: 4,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: isSel ? Theme.of(context).colorScheme.primary : Colors.black45,
                  child: Text('$page', style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ),
              if (isSel)
                const Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReorderGrid extends StatelessWidget {
  const _ReorderGrid({
    required this.path,
    required this.count,
    required this.order,
    required this.onReorder,
  });

  final String path;
  final int count;
  final List<int> order;
  final ValueChanged<List<int>> onReorder;

  void _move(int from, int to) {
    if (to < 0 || to >= count) return;
    final list = List.of(order);
    final item = list.removeAt(from);
    list.insert(to, item);
    onReorder(list);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final page = order[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: PdfThumbnail(path: path, page: page, width: 220),
              ),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black45,
                child: Text('$page', style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),
            Positioned(
              right: 2,
              top: 4,
              child: Row(
                children: [
                  _ArrowBtn(icon: Icons.arrow_back, onTap: i > 0 ? () => _move(i, i - 1) : null),
                  _ArrowBtn(icon: Icons.arrow_forward, onTap: i < count - 1 ? () => _move(i, i + 1) : null),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.black26 : Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

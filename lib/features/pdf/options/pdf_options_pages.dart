import 'package:flutter/material.dart';
import '../../tools/registrar.dart';

import '../../../core/services/picker_service.dart';
import '../../tools/tool_handler.dart';
import 'options_shell.dart';
import '../../../core/models/tool.dart';

class PdfOptionsRegistrar {
  static void registerAll(ToolRegistryReader read) {
    _with('pdf_split', (c, i, o, run) => _SplitOptions(inputs: i, onRun: run));
    _with('pdf_compress', (c, i, o, run) => _CompressOptions(inputs: i, onRun: run));
    _with('pdf_from_image', (c, i, o, run) => _ImageToPdfOptions(inputs: i, onRun: run));
    _with('pdf_from_txt', (c, i, o, run) => _TxtToPdfOptions(inputs: i, onRun: run));
    _with('pdf_to_image', (c, i, o, run) => _ToImageOptions(inputs: i, onRun: run));
    _with('pdf_watermark', (c, i, o, run) => _WatermarkOptions(inputs: i, onRun: run));
    _with('pdf_page_numbers', (c, i, o, run) => _PageNumberOptions(inputs: i, onRun: run));
    _with('pdf_crop', (c, i, o, run) => _CropOptions(inputs: i, onRun: run));
    _with('pdf_metadata', (c, i, o, run) => _MetadataOptions(inputs: i, onRun: run));
    _with('pdf_resize', (c, i, o, run) => _ResizeOptions(inputs: i, onRun: run));
    _with('pdf_grayscale', (c, i, o, run) => _GrayscaleOptions(inputs: i, onRun: run));
    _with('pdf_stamp', (c, i, o, run) => _StampOptions(inputs: i, onRun: run));
    _with('pdf_password', (c, i, o, run) => _PasswordOptions(inputs: i, onRun: run));
    _with('pdf_unlock', (c, i, o, run) => _UnlockOptions(inputs: i, onRun: run));
    _with('pdf_insert', (c, i, o, run) => _InsertOptions(inputs: i, onRun: run, read: read));
    _with('pdf_ocr', (c, i, o, run) => _OcrOptions(inputs: i, onRun: run));
  }

  static void _with(String id, OptionsPageBuilder builder) {
    final existing = ToolHandlerRegistry.handlerFor(id);
    ToolHandlerRegistry.register(id, ToolHandler(
      processor: existing?.processor ?? _delegated,
      optionsBuilder: builder,
    ));
  }

  static Future<ToolResult> _delegated(List<String> inputs, Map<String, dynamic> options,
      {void Function(String, double)? onProgress}) async {
    return ToolResult(error: 'unused');
  }
}

// ════ Individual options widgets ════════════════════════════════

class _SplitOptions extends StatefulWidget {
  const _SplitOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_SplitOptions> createState() => _SplitOptionsState();
}

class _SplitOptionsState extends State<_SplitOptions> {
  String _mode = 'every';
  final _rangesCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'mode': _mode, 'ranges': _rangesCtrl.text}),
      children: [
        OptionSegmented<String>(
          label: 'Split mode',
          value: _mode,
          options: const {'every': 'Every page', 'ranges': 'Custom ranges'},
          onChanged: (v) => setState(() => _mode = v),
        ),
        if (_mode == 'ranges')
          TextField(
            controller: _rangesCtrl,
            decoration: const InputDecoration(
              labelText: 'Ranges',
              hintText: 'e.g. 1-3, 5, 7-9',
              helperText: 'Each range becomes its own PDF',
            ),
          ),
      ],
    );
  }
}

class _CompressOptions extends StatefulWidget {
  const _CompressOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_CompressOptions> createState() => _CompressOptionsState();
}

class _CompressOptionsState extends State<_CompressOptions> {
  String _mode = 'lossless';
  double _dpi = 130;
  double _quality = 60;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'mode': _mode, 'dpi': _dpi.round(), 'quality': _quality.round()}),
      children: [
        OptionSegmented<String>(
          label: 'Method',
          value: _mode,
          options: const {'lossless': 'Lossless (small savings)', 'lossy': 'Recompress pages (smallest file)'},
          onChanged: (v) => setState(() => _mode = v),
        ),
        if (_mode == 'lossy') ...[
          OptionSlider(label: 'Resolution (DPI)', value: _dpi, min: 60, max: 300, onChanged: (v) => setState(() => _dpi = v)),
          OptionSlider(label: 'JPEG quality', value: _quality, min: 20, max: 95, onChanged: (v) => setState(() => _quality = v)),
        ],
      ],
    );
  }
}

class _ImageToPdfOptions extends StatefulWidget {
  const _ImageToPdfOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_ImageToPdfOptions> createState() => _ImageToPdfOptionsState();
}

class _ImageToPdfOptionsState extends State<_ImageToPdfOptions> {
  String _size = 'auto';
  double _quality = 85;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'pageSize': _size, 'quality': _quality.round()}),
      children: [
        OptionSegmented<String>(
          label: 'Page size',
          value: _size,
          options: const {'auto': 'Fit image', 'a4': 'A4', 'a5': 'A5', 'letter': 'Letter'},
          onChanged: (v) => setState(() => _size = v),
        ),
        OptionSlider(label: 'Quality', value: _quality, min: 30, max: 100, onChanged: (v) => setState(() => _quality = v)),
      ],
    );
  }
}

class _TxtToPdfOptions extends StatefulWidget {
  const _TxtToPdfOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_TxtToPdfOptions> createState() => _TxtToPdfOptionsState();
}

class _TxtToPdfOptionsState extends State<_TxtToPdfOptions> {
  double _fontSize = 11;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'fontSize': _fontSize}),
      previewHeight: 100,
      children: [
        OptionSlider(label: 'Font size', value: _fontSize, min: 8, max: 20, onChanged: (v) => setState(() => _fontSize = v)),
      ],
    );
  }
}

class _ToImageOptions extends StatefulWidget {
  const _ToImageOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_ToImageOptions> createState() => _ToImageOptionsState();
}

class _ToImageOptionsState extends State<_ToImageOptions> {
  double _dpi = 150;
  String _format = 'png';

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'dpi': _dpi.round(), 'format': _format}),
      children: [
        OptionSlider(label: 'Resolution (DPI)', value: _dpi, min: 72, max: 400, onChanged: (v) => setState(() => _dpi = v)),
        OptionSegmented<String>(
          label: 'Format',
          value: _format,
          options: const {'png': 'PNG', 'jpeg': 'JPG', 'webp': 'WEBP'},
          onChanged: (v) => setState(() => _format = v),
        ),
      ],
    );
  }
}

class _WatermarkOptions extends StatefulWidget {
  const _WatermarkOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_WatermarkOptions> createState() => _WatermarkOptionsState();
}

class _WatermarkOptionsState extends State<_WatermarkOptions> {
  String _text = 'CONFIDENTIAL';
  double _fontSize = 48;
  double _opacity = 0.25;
  bool _tiled = false;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o, 'text': _text, 'fontSize': _fontSize,
        'opacity': _opacity, 'tiled': _tiled, 'angle': -45.0,
      }),
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Watermark text'),
          onChanged: (v) => _text = v,
        ),
        const SizedBox(height: 8),
        OptionSlider(label: 'Font size', value: _fontSize, min: 12, max: 120, onChanged: (v) => setState(() => _fontSize = v)),
        OptionSlider(label: 'Opacity', value: _opacity * 100, min: 5, max: 80, suffix: '%', onChanged: (v) => setState(() => _opacity = v / 100)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tile across page'),
          value: _tiled,
          onChanged: (v) => setState(() => _tiled = v),
        ),
      ],
    );
  }
}

class _PageNumberOptions extends StatefulWidget {
  const _PageNumberOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_PageNumberOptions> createState() => _PageNumberOptionsState();
}

class _PageNumberOptionsState extends State<_PageNumberOptions> {
  String _alignment = 'bottom-center';
  bool _skipFirst = false;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o,
        'alignment': _alignment,
        'format': 'Page {0} of {1}',
        'skipFirst': _skipFirst,
      }),
      children: [
        OptionSegmented<String>(
          label: 'Position',
          value: _alignment,
          options: const {
            'bottom-center': 'Bottom center',
            'bottom-right': 'Bottom right',
            'bottom-left': 'Bottom left',
            'top-center': 'Top center',
          },
          onChanged: (v) => setState(() => _alignment = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Skip first page'),
          value: _skipFirst,
          onChanged: (v) => setState(() => _skipFirst = v),
        ),
      ],
    );
  }
}

class _CropOptions extends StatefulWidget {
  const _CropOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_CropOptions> createState() => _CropOptionsState();
}

class _CropOptionsState extends State<_CropOptions> {
  double _l = 0, _t = 0, _r = 0, _b = 0;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'left': _l, 'top': _t, 'right': _r, 'bottom': _b}),
      children: [
        OptionSlider(label: 'Left margin', value: _l * 100, min: 0, max: 40, suffix: '%', onChanged: (v) => setState(() => _l = v / 100)),
        OptionSlider(label: 'Top margin', value: _t * 100, min: 0, max: 40, suffix: '%', onChanged: (v) => setState(() => _t = v / 100)),
        OptionSlider(label: 'Right margin', value: _r * 100, min: 0, max: 40, suffix: '%', onChanged: (v) => setState(() => _r = v / 100)),
        OptionSlider(label: 'Bottom margin', value: _b * 100, min: 0, max: 40, suffix: '%', onChanged: (v) => setState(() => _b = v / 100)),
      ],
    );
  }
}

class _MetadataOptions extends StatefulWidget {
  const _MetadataOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_MetadataOptions> createState() => _MetadataOptionsState();
}

class _MetadataOptionsState extends State<_MetadataOptions> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _subject = TextEditingController();
  final _keywords = TextEditingController();
  final _creator = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o,
        'title': _title.text, 'author': _author.text, 'subject': _subject.text,
        'keywords': _keywords.text, 'creator': _creator.text,
      }),
      previewHeight: 100,
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 8),
        TextField(controller: _author, decoration: const InputDecoration(labelText: 'Author')),
        const SizedBox(height: 8),
        TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
        const SizedBox(height: 8),
        TextField(controller: _keywords, decoration: const InputDecoration(labelText: 'Keywords (comma separated)')),
        const SizedBox(height: 8),
        TextField(controller: _creator, decoration: const InputDecoration(labelText: 'Creator')),
      ],
    );
  }
}

class _ResizeOptions extends StatefulWidget {
  const _ResizeOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_ResizeOptions> createState() => _ResizeOptionsState();
}

class _ResizeOptionsState extends State<_ResizeOptions> {
  String _size = 'a4';

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'size': _size}),
      children: [
        OptionSegmented<String>(
          label: 'Target page size',
          value: _size,
          options: const {
            'a4': 'A4', 'a5': 'A5', 'a3': 'A3', 'letter': 'Letter', 'legal': 'Legal', 'b5': 'B5',
          },
          onChanged: (v) => setState(() => _size = v),
        ),
      ],
    );
  }
}

class _GrayscaleOptions extends StatefulWidget {
  const _GrayscaleOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_GrayscaleOptions> createState() => _GrayscaleOptionsState();
}

class _GrayscaleOptionsState extends State<_GrayscaleOptions> {
  double _dpi = 180;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'dpi': _dpi.round()}),
      children: [
        OptionSlider(label: 'Quality (DPI)', value: _dpi, min: 72, max: 300, onChanged: (v) => setState(() => _dpi = v)),
      ],
    );
  }
}

class _StampOptions extends StatefulWidget {
  const _StampOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_StampOptions> createState() => _StampOptionsState();
}

class _StampOptionsState extends State<_StampOptions> {
  String _text = 'APPROVED';
  int _color = 0x1B5E20;
  String _position = 'top-right';

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o, 'text': _text, 'color': _color, 'position': _position,
        'fontSize': 18.0,
      }),
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Stamp text'),
          onChanged: (v) => _text = v,
        ),
        const SizedBox(height: 8),
        OptionSegmented<int>(
          label: 'Color',
          value: _color,
          options: const {0x1B5E20: 'Green', 0xD32F2F: 'Red', 0x1565C0: 'Blue', 0x000000: 'Black'},
          onChanged: (v) => setState(() => _color = v),
        ),
        OptionSegmented<String>(
          label: 'Position',
          value: _position,
          options: const {
            'top-right': 'Top right', 'top-left': 'Top left', 'center': 'Center',
            'bottom-right': 'Bottom right', 'bottom-left': 'Bottom left',
          },
          onChanged: (v) => setState(() => _position = v),
        ),
      ],
    );
  }
}

class _PasswordOptions extends StatefulWidget {
  const _PasswordOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_PasswordOptions> createState() => _PasswordOptionsState();
}

class _PasswordOptionsState extends State<_PasswordOptions> {
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  String _algo = 'aes256';
  String? _error;

  void _run() {
    final p1 = _pwd.text;
    if (p1.isEmpty) {
      setState(() => _error = 'Enter a password');
      return;
    }
    if (p1 != _pwd2.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    widget.onRun({'password': p1, 'algorithm': _algo});
  }

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => _run(),
      children: [
        TextField(controller: _pwd, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        const SizedBox(height: 8),
        TextField(controller: _pwd2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
        const SizedBox(height: 8),
        OptionSegmented<String>(
          label: 'Encryption',
          value: _algo,
          options: const {'aes256': 'AES-256 (best)', 'aes128': 'AES-128', 'rc4': 'RC4-128'},
          onChanged: (v) => setState(() => _algo = v),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}

class _UnlockOptions extends StatefulWidget {
  const _UnlockOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_UnlockOptions> createState() => _UnlockOptionsState();
}

class _UnlockOptionsState extends State<_UnlockOptions> {
  final _pwd = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'password': _pwd.text}),
      children: [
        TextField(
          controller: _pwd,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'PDF password'),
        ),
      ],
    );
  }
}

class _InsertOptions extends StatefulWidget {
  const _InsertOptions({required this.inputs, required this.onRun, required this.read});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;
  final ToolRegistryReader read;

  @override
  State<_InsertOptions> createState() => _InsertOptionsState();
}

class _InsertOptionsState extends State<_InsertOptions> {
  String? _insertPath;
  double _position = 0;

  Future<void> _pick() async {
    final paths = await widget.read(pickerServiceProvider)
        .pickForType(ToolInputType.pdf, multiple: false);
    if (paths.isNotEmpty) setState(() => _insertPath = paths.first);
  }

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o,
        'insertPath': _insertPath,
        'position': _position.round(),
      }),
      children: [
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(_insertPath == null
              ? 'Pick PDF to insert'
              : _insertPath!.split('/').last),
        ),
        const SizedBox(height: 12),
        OptionSlider(
          label: 'Insert after page (0 = beginning)',
          value: _position,
          min: 0,
          max: 100,
          onChanged: (v) => setState(() => _position = v),
        ),
      ],
    );
  }
}

class _OcrOptions extends StatefulWidget {
  const _OcrOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_OcrOptions> createState() => _OcrOptionsState();
}

class _OcrOptionsState extends State<_OcrOptions> {
  double _dpi = 200;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'dpi': _dpi.round()}),
      children: [
        OptionSlider(
          label: 'OCR resolution (DPI)',
          value: _dpi,
          min: 100,
          max: 300,
          onChanged: (v) => setState(() => _dpi = v),
        ),
        const Text('Runs fully on-device with Google ML Kit. No internet needed.'),
      ],
    );
  }
}

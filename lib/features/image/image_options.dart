import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../tools/tool_handler.dart';
import '../pdf/options/options_shell.dart';
import '../tools/registrar.dart';

class ImageOptionsRegistrar {
  static void registerAll(ToolRegistryReader read) {
    _with('img_compress', (c, i, o, run) => _CompressOptions(inputs: i, onRun: run));
    _with('img_resize', (c, i, o, run) => _ResizeOptions(inputs: i, onRun: run));
    _with('img_rotate', (c, i, o, run) => _RotateOptions(inputs: i, onRun: run));
    _with('img_convert', (c, i, o, run) => _ConvertOptions(inputs: i, onRun: run));
    _with('img_collage', (c, i, o, run) => _CollageOptions(inputs: i, onRun: run));
    _with('img_adjust', (c, i, o, run) => _AdjustOptions(inputs: i, onRun: run));
    _with('img_watermark', (c, i, o, run) => _WatermarkOptions(inputs: i, onRun: run));
    _with('img_border', (c, i, o, run) => _BorderOptions(inputs: i, onRun: run));
    _with('img_photo_layout', (c, i, o, run) => _PhotoLayoutOptions(inputs: i, onRun: run));
    _with('img_crop', (c, i, o, run) => _CropLauncher(inputs: i, onRun: run));
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

class _CompressOptions extends StatefulWidget {
  const _CompressOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_CompressOptions> createState() => _CompressOptionsState();
}

class _CompressOptionsState extends State<_CompressOptions> {
  double _quality = 70;
  int? _maxWidth;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'quality': _quality.round(), 'maxWidth': _maxWidth}),
      children: [
        OptionSlider(label: 'JPEG quality', value: _quality, min: 10, max: 95, onChanged: (v) => setState(() => _quality = v)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Limit width'),
          subtitle: Text(_maxWidth == null ? 'Off' : '${_maxWidth}px'),
          value: _maxWidth != null,
          onChanged: (v) => setState(() => _maxWidth = v ? 1600 : null),
        ),
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
  final _w = TextEditingController();
  final _h = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o,
        'width': int.tryParse(_w.text),
        'height': int.tryParse(_h.text),
      }),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _w,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Width (px)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _h,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height (px)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Leave one blank to keep aspect ratio.'),
      ],
    );
  }
}

class _RotateOptions extends StatefulWidget {
  const _RotateOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_RotateOptions> createState() => _RotateOptionsState();
}

class _RotateOptionsState extends State<_RotateOptions> {
  String _mode = '90';

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'mode': _mode}),
      children: [
        OptionSegmented<String>(
          label: 'Transform',
          value: _mode,
          options: const {
            '90': 'Rotate 90°',
            '180': 'Rotate 180°',
            '270': 'Rotate 270°',
            'flipH': 'Flip horizontal',
            'flipV': 'Flip vertical',
          },
          onChanged: (v) => setState(() => _mode = v),
        ),
      ],
    );
  }
}

class _ConvertOptions extends StatefulWidget {
  const _ConvertOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_ConvertOptions> createState() => _ConvertOptionsState();
}

class _ConvertOptionsState extends State<_ConvertOptions> {
  String _format = 'png';
  double _quality = 85;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'format': _format, 'quality': _quality.round()}),
      children: [
        OptionSegmented<String>(
          label: 'Target format',
          value: _format,
          options: const {'jpg': 'JPG', 'png': 'PNG', 'webp': 'WEBP', 'bmp': 'BMP', 'gif': 'GIF'},
          onChanged: (v) => setState(() => _format = v),
        ),
        OptionSlider(label: 'Quality', value: _quality, min: 20, max: 100, onChanged: (v) => setState(() => _quality = v)),
      ],
    );
  }
}

class _CollageOptions extends StatefulWidget {
  const _CollageOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_CollageOptions> createState() => _CollageOptionsState();
}

class _CollageOptionsState extends State<_CollageOptions> {
  int _cols = 2;
  String _mode = 'grid';

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'cols': _cols, 'mode': _mode}),
      children: [
        OptionSegmented<String>(
          label: 'Layout',
          value: _mode,
          options: const {'grid': 'Grid', 'horizontal': 'Side by side'},
          onChanged: (v) => setState(() => _mode = v),
        ),
        if (_mode == 'grid')
          OptionSegmented<int>(
            label: 'Columns',
            value: _cols,
            options: const {1: '1', 2: '2', 3: '3', 4: '4'},
            onChanged: (v) => setState(() => _cols = v),
          ),
      ],
    );
  }
}

class _AdjustOptions extends StatefulWidget {
  const _AdjustOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_AdjustOptions> createState() => _AdjustOptionsState();
}

class _AdjustOptionsState extends State<_AdjustOptions> {
  double _brightness = 0;
  double _contrast = 1;
  double _saturation = 1;
  double _sharpen = 0;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o,
        'brightness': _brightness,
        'contrast': _contrast,
        'saturation': _saturation,
        'sharpen': _sharpen,
      }),
      children: [
        OptionSlider(label: 'Brightness', value: _brightness * 100, min: -50, max: 50, onChanged: (v) => setState(() => _brightness = v / 100)),
        OptionSlider(label: 'Contrast', value: _contrast * 100, min: 20, max: 200, onChanged: (v) => setState(() => _contrast = v / 100)),
        OptionSlider(label: 'Saturation', value: _saturation * 100, min: 0, max: 200, onChanged: (v) => setState(() => _saturation = v / 100)),
        OptionSlider(label: 'Sharpen', value: _sharpen * 100, min: 0, max: 100, onChanged: (v) => setState(() => _sharpen = v / 100)),
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
  String _text = 'WATERMARK';
  String _position = 'center';
  double _scale = 0.4;
  double _opacity = 0.5;
  bool _tiled = false;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({
        ...o, 'text': _text, 'position': _position,
        'scale': _scale, 'opacity': _opacity, 'tiled': _tiled,
      }),
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Watermark text'),
          onChanged: (v) => _text = v,
        ),
        const SizedBox(height: 8),
        OptionSegmented<String>(
          label: 'Position',
          value: _position,
          options: const {
            'center': 'Center', 'top-left': 'Top left', 'top-right': 'Top right',
            'bottom-left': 'Bottom left', 'bottom-right': 'Bottom right',
          },
          onChanged: (v) => setState(() => _position = v),
        ),
        OptionSlider(label: 'Size', value: _scale * 100, min: 10, max: 90, suffix: '%', onChanged: (v) => setState(() => _scale = v / 100)),
        OptionSlider(label: 'Opacity', value: _opacity * 100, min: 5, max: 100, suffix: '%', onChanged: (v) => setState(() => _opacity = v / 100)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tile across image'),
          value: _tiled,
          onChanged: (v) => setState(() => _tiled = v),
        ),
      ],
    );
  }
}

class _BorderOptions extends StatefulWidget {
  const _BorderOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_BorderOptions> createState() => _BorderOptionsState();
}

class _BorderOptionsState extends State<_BorderOptions> {
  int _color = 0xFFFFFF;
  double _thickness = 40;

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'color': _color, 'thickness': _thickness.round()}),
      children: [
        OptionSegmented<int>(
          label: 'Border color',
          value: _color,
          options: const {
            0xFFFFFF: 'White', 0x000000: 'Black', 0xD32F2F: 'Red',
            0x1565C0: 'Blue', 0xF57C00: 'Orange', 0x1B5E20: 'Green',
          },
          onChanged: (v) => setState(() => _color = v),
        ),
        OptionSlider(label: 'Thickness', value: _thickness, min: 4, max: 200, suffix: 'px', onChanged: (v) => setState(() => _thickness = v)),
      ],
    );
  }
}

class _PhotoLayoutOptions extends StatefulWidget {
  const _PhotoLayoutOptions({required this.inputs, required this.onRun});
  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  State<_PhotoLayoutOptions> createState() => _PhotoLayoutOptionsState();
}

class _PhotoLayoutOptionsState extends State<_PhotoLayoutOptions> {
  String _layout = 'passport';

  @override
  Widget build(BuildContext context) {
    return OptionsShell(
      inputs: widget.inputs,
      onRun: (o) => widget.onRun({...o, 'layout': _layout}),
      children: [
        OptionSegmented<String>(
          label: 'Layout',
          value: _layout,
          options: const {
            'passport': 'Passport (2x3)',
            'id35x45': 'ID 35×45mm (2x3)',
            'visa2x2': 'Visa 2×2" (2x2)',
            'photo10x15': '10×15cm (2x2)',
          },
          onChanged: (v) => setState(() => _layout = v),
        ),
        const Text('Output is an A4 sheet (300 dpi) ready for printing.'),
      ],
    );
  }
}

class _CropLauncher extends StatelessWidget {
  const _CropLauncher({required this.inputs, required this.onRun});

  final List<String> inputs;
  final ValueChanged<Map<String, dynamic>> onRun;

  Future<void> _launch(BuildContext context) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: inputs.first,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: Color(0xFF1565C0),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
      ],
    );
    if (cropped == null || cropped.path.isEmpty) return;
    onRun({'resultPath': cropped.path});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.crop, size: 72, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Opens the crop editor. Pick the region, confirm, and the cropped image is ready to save or share.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.crop),
                label: const Text('Open crop editor'),
                onPressed: () => _launch(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

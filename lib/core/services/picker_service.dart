import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool.dart';

class PickerService {
  Future<List<String>> pickForType(ToolInputType type, {bool multiple = false}) async {
    if (kIsWeb) return [];
    List<PlatformFile> result;
    switch (type) {
      case ToolInputType.pdf:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.image:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.txt:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['txt', 'md', 'text'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.csv:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.html:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['html', 'htm'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.docx:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['docx', 'doc'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.xlsx:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.pptx:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pptx', 'ppt'],
          allowMultiple: multiple,
        );
        break;
      case ToolInputType.zip:
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
          allowMultiple: false,
        );
        break;
      case ToolInputType.any:
      case ToolInputType.none:
        result = await FilePicker.pickFiles(allowMultiple: multiple);
        break;
    }
    final paths = result.map((f) => f.path).whereType<String>().toList();
    return paths..sort();
  }

  Future<List<String>> pickAny({bool multiple = false}) async {
    if (kIsWeb) return [];
    final result = await FilePicker.pickFiles(allowMultiple: multiple);
    return result.map((f) => f.path).whereType<String>().toList();
  }

  Future<String?> pickDirectory() async {
    if (kIsWeb) return null;
    final dir = await FilePicker.getDirectoryPath();
    return dir;
  }
}

final pickerServiceProvider = Provider<PickerService>((ref) => PickerService());

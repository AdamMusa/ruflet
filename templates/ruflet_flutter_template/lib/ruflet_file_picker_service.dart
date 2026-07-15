import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flet/flet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class RufletFilePickerExtension extends FletExtension {
  @override
  FletService? createService(Control control) {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.macOS &&
        control.type == 'FilePicker') {
      return RufletFilePickerService(control: control);
    }
    return null;
  }
}

class RufletFilePickerService extends FletService {
  RufletFilePickerService({required super.control});

  List<PlatformFile>? _files;

  @override
  void init() {
    super.init();
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    final methodArgs = args is Map ? args : const {};
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    switch (name) {
      case 'pick_files':
        final result = await FilePicker.platform.pickFiles(
          type: _fileType(methodArgs['file_type']),
          allowedExtensions: _stringList(methodArgs['allowed_extensions']),
          allowMultiple: methodArgs['allow_multiple'] == true,
          withData: methodArgs['with_data'] == true,
          withReadStream: false,
        );
        _files = result?.files;
        return _files == null
            ? []
            : _files!.asMap().entries.map((entry) {
                final file = entry.value;
                return {
                  'id': entry.key,
                  'name': file.name,
                  'path': file.path,
                  'size': file.size,
                  'bytes': file.bytes,
                };
              }).toList();
      case 'save_file':
        return FilePicker.platform.saveFile(
          fileName: methodArgs['file_name']?.toString(),
          type: _fileType(methodArgs['file_type']),
          allowedExtensions: _stringList(methodArgs['allowed_extensions']),
          bytes: _bytes(methodArgs['src_bytes']),
        );
      case 'get_directory_path':
        return FilePicker.platform.getDirectoryPath();
      case 'upload':
        return null;
      default:
        throw Exception('Unknown FilePicker method: $name');
    }
  }

  FileType _fileType(dynamic value) {
    switch (value.toString()) {
      case 'audio':
        return FileType.audio;
      case 'custom':
        return FileType.custom;
      case 'image':
        return FileType.image;
      case 'media':
        return FileType.media;
      case 'video':
        return FileType.video;
      default:
        return FileType.any;
    }
  }

  List<String>? _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return null;
  }

  Uint8List? _bytes(dynamic value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List) {
      return Uint8List.fromList(value.map((item) => item as int).toList());
    }
    return Uint8List.fromList(utf8.encode(value.toString()));
  }
}

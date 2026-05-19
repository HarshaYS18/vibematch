import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class InboxVoiceRecordingResult {
  const InboxVoiceRecordingResult({required this.path, required this.bytes, required this.duration});

  final String path;
  final List<int> bytes;
  final Duration duration;

  bool get isTooShort => duration < const Duration(milliseconds: 700);
  bool get isTooLarge => bytes.length > 10 * 1024 * 1024;
  String get filename => 'funkey_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

class InboxVoiceRecorderService {
  InboxVoiceRecorderService();

  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;
  String? _currentPath;

  Future<bool> get isRecording => _recorder.isRecording();

  Future<bool> start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission && !kIsWeb) return false;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/funkey_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    _startedAt = DateTime.now();
    _currentPath = path;

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );
      return true;
    } catch (_) {
      _startedAt = null;
      _currentPath = null;
      return false;
    }
  }

  Future<InboxVoiceRecordingResult?> stop() async {
    final stoppedPath = await _recorder.stop();
    final startedAt = _startedAt;
    final path = stoppedPath ?? _currentPath;
    _startedAt = null;
    _currentPath = null;
    if (path == null || startedAt == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return InboxVoiceRecordingResult(path: path, bytes: bytes, duration: DateTime.now().difference(startedAt));
  }

  Future<void> cancel() async {
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _currentPath;
    _startedAt = null;
    _currentPath = null;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

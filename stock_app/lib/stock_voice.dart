import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Decodes a base64 `data:audio/...;base64,` string into bytes (or null).
Uint8List? stockVoiceBytes(dynamic voice) {
  if (voice is String && voice.isNotEmpty) {
    final i = voice.indexOf(',');
    if (i >= 0) {
      try {
        return base64Decode(voice.substring(i + 1));
      } catch (_) {}
    }
  }
  return null;
}

String fmtVoiceDur(int? ms) {
  if (ms == null || ms <= 0) return '';
  final totalSec = (ms / 1000).round();
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Play/pause chip for an already-decoded voice note.
class VoicePlayerChip extends StatefulWidget {
  final Uint8List bytes;
  final int durationMs;
  final Color color;
  const VoicePlayerChip({
    super.key,
    required this.bytes,
    this.durationMs = 0,
    required this.color,
  });

  @override
  State<VoicePlayerChip> createState() => _VoicePlayerChipState();
}

class _VoicePlayerChipState extends State<VoicePlayerChip> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration? _total;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.durationMs);
    _posSub = _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
      return;
    }
    try {
      await _player.setSource(BytesSource(widget.bytes));
      if (_pos > Duration.zero && (_total == null || _pos < _total!)) {
        await _player.seek(_pos);
      }
      await _player.resume();
      if (mounted) setState(() => _playing = true);
    } catch (_) {}
  }

  int get _durationMs {
    if (_playing) return _pos.inMilliseconds;
    return widget.durationMs;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _toggle,
                child: Icon(
                  _playing ? Icons.stop_circle : Icons.play_circle_fill,
                  size: 24,
                  color: c,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.graphic_eq, size: 14),
              const SizedBox(width: 4),
              Text(
                fmtVoiceDur(_durationMs).isEmpty ? 'Voice' : fmtVoiceDur(_durationMs),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
          if (_playing && widget.durationMs > 0 && _total != null && _total!.inMilliseconds > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_pos.inMilliseconds / _total!.inMilliseconds).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: c.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class VoiceRecordingResult {
  final Uint8List bytes;
  final int durationMs;
  VoiceRecordingResult(this.bytes, this.durationMs);
}

/// Mic button: tap to record (max 60s), tap again to stop. Shows the recorded
/// clip with an inline player + remove button.
class VoiceRecorderButton extends StatefulWidget {
  final Color color;
  final String? label;
  final void Function(VoiceRecordingResult evidence) onRecorded;
  final void Function() onCleared;
  const VoiceRecorderButton({
    super.key,
    required this.onRecorded,
    required this.onCleared,
    this.color = const Color(0xFFA78BFA),
    this.label,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  bool _recording = false;
  DateTime? _started;
  VoiceRecordingResult? _result;
  String? _err;

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecord();
      return;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _err = 'Microphone permission nahi mili');
      return;
    }
    String path = '';
    try {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/stock_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 22050,
          bitRate: 32000,
        ),
        path: path,
      );
      _started = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
        if (_started != null) {
          final el = DateTime.now().difference(_started!);
          if (el > const Duration(seconds: 60)) _stopRecord();
        }
      });
      if (mounted) setState(() {
        _recording = true;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = 'Record start fail');
    }
  }

  Future<void> _stopRecord() async {
    _ticker?.cancel();
    _ticker = null;
    final dur = _started == null ? Duration.zero : DateTime.now().difference(_started!);
    _started = null;
    String? p;
    try {
      p = await _recorder.stop();
    } catch (_) {}
    if (p != null && p.isNotEmpty) {
      try {
        final f = File(p);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          try {
            await f.delete();
          } catch (_) {}
          if (mounted) {
            setState(() {
              _recording = false;
              _result = VoiceRecordingResult(bytes, dur.inMilliseconds);
              _err = null;
            });
          }
          widget.onRecorded(_result!);
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _recording = false;
        _err = dur.inSeconds < 1 ? 'Recording bht chhoti hai (1s se kam)' : 'Recording save nahi hui';
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final res = _result;
    if (res != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoicePlayerChip(bytes: res.bytes, durationMs: res.durationMs, color: c),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              widget.onCleared();
              setState(() => _result = null);
            },
            child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
          ),
        ],
      );
    }
    final elapsed =
        _recording && _started != null ? DateTime.now().difference(_started!) : Duration.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggleRecord,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _recording
                  ? const Color(0xFFDC2626).withOpacity(0.15)
                  : c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _recording ? const Color(0xFFDC2626) : c.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _recording ? Icons.stop_circle : Icons.mic,
                  size: 20,
                  color: _recording ? const Color(0xFFDC2626) : c,
                ),
                const SizedBox(width: 6),
                Text(
                  _recording
                      ? 'Stop (${fmtVoiceDur(elapsed.inMilliseconds)})'
                      : (widget.label ?? 'Voice note record'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _recording ? const Color(0xFFDC2626) : c,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_err!, style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
          ),
      ],
    );
  }
}
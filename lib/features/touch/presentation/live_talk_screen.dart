import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/providers.dart';
import '../../../core/theme/resonant_theme.dart';
import '../data/touch_repository.dart';

/// Talk live: a real conversation with the tutor about this picture.
/// The phone joins a LiveKit room; the agent (agent/) listens, thinks with
/// Muse Spark and speaks. Talking over it interrupts it — that is the point.
/// Captions show both sides so the conversation is also readable.
class LiveTalkScreen extends ConsumerStatefulWidget {
  const LiveTalkScreen({super.key, required this.connection, required this.title});
  final LiveVoiceConnection connection;
  final String title;

  @override
  ConsumerState<LiveTalkScreen> createState() => _LiveTalkScreenState();
}

class _LiveTalkScreenState extends ConsumerState<LiveTalkScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String _status = 'Connecting…';
  bool _micOn = true;
  bool _agentSpeaking = false;
  final List<({String who, String text})> _lines = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
    _room = room;
    _listener = room.createListener()
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted) setState(() => _status = 'Call ended.');
      })
      ..on<ParticipantConnectedEvent>((e) {
        if (e.participant.identity.startsWith('agent') && mounted) {
          setState(() => _status = 'Tutor joined. Just talk — you can interrupt.');
        }
      })
      ..on<ActiveSpeakersChangedEvent>((e) {
        if (!mounted) return;
        final agentTalking = e.speakers.any((p) => p.identity.startsWith('agent'));
        setState(() {
          _agentSpeaking = agentTalking;
          _status = agentTalking
              ? 'Tutor is talking — start speaking to interrupt.'
              : 'Listening. Just talk.';
        });
      });
    // Both sides' transcriptions arrive as text streams on this topic.
    room.registerTextStreamHandler('lk.transcription', (reader, participantIdentity) async {
      final text = (await reader.readAll()).trim();
      if (!mounted || text.isEmpty) return;
      final who = participantIdentity.startsWith('agent') ? 'Tutor' : 'You';
      setState(() {
        _lines.add((who: who, text: text));
        if (_lines.length > 30) _lines.removeAt(0);
      });
    });
    try {
      await room.connect(widget.connection.url, widget.connection.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (mounted) setState(() => _status = 'Connected. Waiting for the tutor…');
      ref.read(speechProvider).speak('Live tutor. Just talk, and you can interrupt it.');
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not connect. Check the connection and try again.');
    }
  }

  Future<void> _end() async {
    await _room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _room?.unregisterTextStreamHandler('lk.transcription');
    _listener?.dispose();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _end,
                  tooltip: 'End live talk',
                  icon: Icon(Icons.arrow_back, color: p.ink),
                  iconSize: 28,
                  constraints: const BoxConstraints(minWidth: minTouchTarget, minHeight: minTouchTarget),
                ),
              ),
              Semantics(header: true, child: Text('Talk live', style: brandStyle(36, p.ink))),
              const SizedBox(height: 4),
              Text(widget.title, style: TextStyle(fontSize: 19, color: p.ink, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _status,
                  style: TextStyle(fontSize: 20, color: p.ink, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    for (final line in _lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${line.who}: ${line.text}',
                          style: TextStyle(fontSize: 19, color: p.ink, height: 1.35),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () async {
                      final on = !_micOn;
                      await _room?.localParticipant?.setMicrophoneEnabled(on);
                      if (mounted) setState(() => _micOn = on);
                    },
                    child: Text(_micOn ? 'Mute' : 'Unmute'),
                  ),
                  FilledButton(onPressed: _end, child: const Text('End talk')),
                ],
              ),
              if (_agentSpeaking) ...[
                const SizedBox(height: 8),
                Text(
                  'Tip: just start talking to interrupt the tutor.',
                  style: TextStyle(fontSize: 16, color: p.ink),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

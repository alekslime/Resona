import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/providers.dart';
import '../../../core/ui/resonant_controls.dart';
import '../../../core/ui/resonant_dots.dart';
import '../../../core/ui/resonant_scaffold.dart';
import '../data/touch_repository.dart';

/// Which dots the live room shows: orbiting while the call sets up, the
/// speaking wave while the tutor talks, the listening lean otherwise.
DotsState talkDotsState({
  required bool connecting,
  required bool agentSpeaking,
  required bool micOn,
}) {
  if (connecting) return DotsState.thinking;
  if (agentSpeaking) return DotsState.speaking;
  if (micOn) return DotsState.listening;
  return DotsState.idle;
}

/// One caption from the student, right-aligned like old Chat's user lines.
/// The speaker stays in the spoken label, so screen readers keep what the
/// old "You: …" prefix said.
class UserLine extends ConsumerWidget {
  const UserLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = ref.watch(paletteProvider).ink;
    final font = ref.watch(fontProvider);
    return Semantics(
      label: 'You: $text',
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          fontFamily: font.family,
          color: ink,
        ),
      ),
    );
  }
}

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
  bool _connecting = true;
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
        if (mounted) {
          setState(() {
            _status = 'Call ended.';
            _connecting = false;
            _agentSpeaking = false;
          });
        }
      })
      ..on<ParticipantConnectedEvent>((e) {
        if (e.participant.identity.startsWith('agent') && mounted) {
          setState(() {
            _status = 'Tutor joined. Just talk — you can interrupt.';
            _connecting = false;
          });
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
      if (mounted) {
        setState(() {
          _status = 'Could not connect. Check the connection and try again.';
          _connecting = false;
        });
      }
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
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final dots = talkDotsState(
      connecting: _connecting,
      agentSpeaking: _agentSpeaking,
      micOn: _micOn,
    );
    return ResonantScaffold(
      title: 'Talk live',
      subtitle: widget.title,
      onBack: () {
        unawaited(_end());
      },
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            Center(
              child: DotsPing(
                state: dots,
                child: ResonantDots(
                  state: dots,
                  size: 88,
                  color: palette.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ResonantButton(
                    text: _micOn ? 'Mute' : 'Unmute',
                    onPressed: () async {
                      final on = !_micOn;
                      await _room?.localParticipant?.setMicrophoneEnabled(on);
                      if (mounted) setState(() => _micOn = on);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ResonantButton(
                    text: 'End talk',
                    filled: false,
                    onPressed: () {
                      unawaited(_end());
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final line in _lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: line.who == 'You'
                          ? UserLine(line.text)
                          : Semantics(
                              label: 'Tutor: ${line.text}',
                              child: Text(
                                line.text,
                                style: TextStyle(
                                  fontFamily: font.family,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ink,
                                  height: 1.35,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
            if (_agentSpeaking) ...[
              const SizedBox(height: 8),
              Text(
                'Tip: just start talking to interrupt the tutor.',
                style: TextStyle(
                    fontFamily: font.family, fontSize: 16, color: palette.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

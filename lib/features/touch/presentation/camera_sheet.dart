import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';

import '../../../core/ui/resonant_controls.dart';
import '../application/pictures_controller.dart';
import '../data/touch_repository.dart';
import 'gesture_guide.dart';

/// The sheet behind the chat pill's camera button: take a photo, choose from
/// the gallery, try a sample, or reopen a recent. Returns the attached
/// picture, or null when dismissed. Failures speak and stay open for a retry.
Future<RecentPicture?> showCameraSheet(BuildContext context,
    {ImagePicker? picker}) {
  return showModalBottomSheet<RecentPicture?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CameraSheet(picker: picker ?? ImagePicker()),
  ).then((value) => value);
}

class _CameraSheet extends ConsumerStatefulWidget {
  const _CameraSheet({required this.picker});

  final ImagePicker picker;

  @override
  ConsumerState<_CameraSheet> createState() => _CameraSheetState();
}

class _CameraSheetState extends ConsumerState<_CameraSheet> {
  List<GallerySample>? _gallery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(speechProvider).speak(
          'Add a picture. Take a photo, choose from the gallery, or try a sample.');
    });
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    // Never throws: offline, the repository answers with the bundled pictures.
    final entries = await ref.read(repositoryProvider).gallery();
    if (mounted) {
      setState(() => _gallery = entries);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (ref.read(picturesControllerProvider).busy) return;
    final file = await widget.picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ??
        (file.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg');
    final recent = await ref
        .read(picturesControllerProvider.notifier)
        .analyze(PictureBytes(bytes, mime));
    if (recent != null && mounted) {
      Navigator.of(context).pop(recent);
    }
  }

  Future<void> _openSample(GallerySample entry) async {
    if (ref.read(picturesControllerProvider).busy) return;
    final recent = await ref
        .read(picturesControllerProvider.notifier)
        .openGallery(entry);
    if (recent != null && mounted) {
      Navigator.of(context).pop(recent);
    }
  }

  void _openRecent(RecentPicture recent) {
    if (ref.read(picturesControllerProvider).busy) return;
    final attached = ref
        .read(picturesControllerProvider.notifier)
        .openRecent(recent);
    Navigator.of(context).pop(attached);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final state = ref.watch(picturesControllerProvider);
    final gallery = _gallery ?? bundledSamples;
    final status =
        state.busy ? state.progress : state.message;
    return Container(
      color: palette.background,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FirstVisitGuide(screen: GuideScreen.camera),
            Text(
              'Add a picture',
              style: TextStyle(
                fontFamily: font.family,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 12),
            if (status.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
              ),
            ResonantButton(
              text: 'Take photo',
              onPressed: () => _pick(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            ResonantButton(
              text: 'Choose from gallery',
              onPressed: () => _pick(ImageSource.gallery),
            ),
            const SizedBox(height: 20),
            _SectionHead('Try a sample', palette.ink, font.family),
            const SizedBox(height: 8),
            for (final entry in gallery)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ResonantButton(
                  text: '${entry.title} (${entry.regions} parts)',
                  filled: false,
                  onPressed: () => _openSample(entry),
                ),
              ),
            if (state.recents.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionHead('Recent pictures', palette.ink, font.family),
              const SizedBox(height: 8),
              for (final recent in state.recents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ResonantButton(
                    text:
                        '${recent.analysis.title} (${recent.analysis.regions.length} parts)',
                    filled: false,
                    onPressed: () => _openRecent(recent),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.text, this.color, this.fontFamily);

  final String text;
  final Color color;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Ultra-fast version using rawRgba format (no encoding/decoding overhead)
Future<({Uint8List bytes, int width, int height})> resizeImage$RawRgba(
  Uint8List bytes,
  double scale,
) async {
  var dispose = () {};
  void disposable(void Function() callback) {
    var fn = dispose;
    dispose = () {
      try {
        fn();
      } finally {
        callback();
      }
    };
  }

  try {
    final codec = await ui.instantiateImageCodec(bytes, allowUpscaling: false);
    disposable(codec.dispose);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    disposable(src.dispose);

    final src$width = src.width, src$height = src.height;
    final int dst$width, dst$height;

    switch (scale) {
      case 2.0:
        dst$width = src$width << 1;
        dst$height = src$height << 1;
      case 0.5:
        dst$width = src$width >> 1;
        dst$height = src$height >> 1;
      case 4.0:
        dst$width = src$width << 2;
        dst$height = src$height << 2;
      case 0.25:
        dst$width = src$width >> 2;
        dst$height = src$height >> 2;
      default:
        dst$width = (src$width * scale).toInt();
        dst$height = (src$height * scale).toInt();
    }

    if (dst$width == src$width && dst$height == src$height) {
      // Return original as rawRgba
      final byteData = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null)
        throw StateError('Failed to convert image to raw bytes');
      return (
        bytes: byteData.buffer.asUint8List(),
        width: src$width,
        height: src$height,
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, dst$width.toDouble(), dst$height.toDouble()),
    );

    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..blendMode = ui.BlendMode.src
      ..isAntiAlias = false;

    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src$width.toDouble(), src$height.toDouble()),
      ui.Rect.fromLTWH(0, 0, dst$width.toDouble(), dst$height.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    disposable(picture.dispose);
    final resizedImage = picture.toImageSync(dst$width, dst$height);
    disposable(resizedImage.dispose);

    // Use rawRgba - much faster than PNG encoding
    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null)
      throw StateError('Failed to convert resized image to byte data');

    return (
      bytes: byteData.buffer.asUint8List(),
      width: dst$width,
      height: dst$height,
    );
  } finally {
    dispose();
  }
}

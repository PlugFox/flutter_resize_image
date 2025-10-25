// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Resize image [bytes] by [scale] using Flutter's image codec and canvas.
Future<Uint8List> resizeImage$Flutter(Uint8List bytes, double scale) async {
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

    if (dst$width == src$width && dst$height == src$height) return bytes;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..blendMode = ui.BlendMode.src
      ..isAntiAlias = false;

    canvas.drawImageRect(
      src,
      ui.Rect.fromLTRB(0, 0, src$width.toDouble(), src$height.toDouble()),
      ui.Rect.fromLTRB(0, 0, dst$width.toDouble(), dst$height.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    disposable(picture.dispose);
    final resizedImage = picture.toImageSync(dst$width, dst$height);
    disposable(resizedImage.dispose);
    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null)
      throw StateError('Failed to convert resized image to byte data');

    return byteData.buffer.asUint8List();
  } on Object {
    rethrow;
  } finally {
    dispose();
  }
}

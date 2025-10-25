import 'dart:typed_data';
import 'dart:ui' as ui;

Future<Uint8List> resizeImage$Flutter(Uint8List bytes, double scale) async {
  final codec = await ui.instantiateImageCodec(bytes, allowUpscaling: false);
  final frame = await codec.getNextFrame();
  final src = frame.image;

  final srcWidth = src.width;
  final srcHeight = src.height;
  final int dstWidth;
  final int dstHeight;

  if (scale == 2.0) {
    dstWidth = srcWidth << 1;
    dstHeight = srcHeight << 1;
  } else if (scale == 0.5) {
    dstWidth = srcWidth >> 1;
    dstHeight = srcHeight >> 1;
  } else if (scale == 4.0) {
    dstWidth = srcWidth << 2;
    dstHeight = srcHeight << 2;
  } else if (scale == 0.25) {
    dstWidth = srcWidth >> 2;
    dstHeight = srcHeight >> 2;
  } else {
    dstWidth = (srcWidth * scale).toInt();
    dstHeight = (srcHeight * scale).toInt();
  }

  if (dstWidth == srcWidth && dstHeight == srcHeight) {
    src.dispose();
    codec.dispose();
    return bytes;
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..blendMode = ui.BlendMode.src
    ..isAntiAlias = false;

  canvas.drawImageRect(
    src,
    ui.Rect.fromLTWH(0, 0, srcWidth.toDouble(), srcHeight.toDouble()),
    ui.Rect.fromLTWH(0, 0, dstWidth.toDouble(), dstHeight.toDouble()),
    paint,
  );

  final picture = recorder.endRecording();
  final resizedImage = picture.toImageSync(dstWidth, dstHeight);
  final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
  final result = byteData!.buffer.asUint8List();

  src.dispose();
  resizedImage.dispose();
  picture.dispose();
  codec.dispose();

  return result;
}

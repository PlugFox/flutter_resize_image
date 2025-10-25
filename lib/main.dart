import 'dart:async';
import 'dart:io' as io;

import 'package:resize/src/binding.dart';
import 'package:resize/src/png_encoder_gdi.dart';
import 'package:resize/src/resize_image.dart';
import 'package:resize/src/utils.dart';

final $log = io.stdout.writeln;
final $err = io.stderr.writeln;

void main([List<String>? args]) => runZonedGuarded<void>(
  () async {
    Binding.instance.ensureInitialized();
    io.File inputFile;
    {
      switch (io.Platform.environment['CONFIG_IMAGE_PATH']?.trim()) {
        case null:
          $err('CONFIG_IMAGE_PATH is not set');
          io.exit(1);
        case '':
          $err('CONFIG_IMAGE_PATH is empty');
          io.exit(1);
        case final path:
          inputFile = io.File(path);
          if (!inputFile.existsSync()) {
            $err('Image file does not exist: $path');
            io.exit(1);
          }
      }
    }

    final outputFile = io.File(
      '${inputFile.path.replaceAll(RegExp(r'\.[^.]+$'), '')}'
      '.resized.png',
    );

    final inputBytes = inputFile.readAsBytesSync();
    $log(
      'Read: '
      '${inputFile.path} '
      '(${bytesToHumanReadableString(inputBytes.lengthInBytes)})',
    );

    const scale = 2.0;

    final stopwatch = Stopwatch()..start();
    final output = await resizeImage$RawRgba(inputBytes, scale);
    final resizeTime = stopwatch.elapsedMilliseconds;
    $log('Resized in $resizeTime ms');

    stopwatch.reset();
    stopwatch.start();
    final bytes = encodePngGdi(output.bytes, output.width, output.height);
    stopwatch.stop();
    $log('Encoded PNG in ${stopwatch.elapsedMilliseconds} ms');

    outputFile.writeAsBytesSync(bytes);

    $log(
      'Saved: '
      '${outputFile.path} '
      '(${bytesToHumanReadableString(bytes.lengthInBytes)})',
    );

    io.exit(0);
  },
  (e, s) {
    $err('Error: $e\nStack trace:\n$s');
    io.exit(1);
  },
);

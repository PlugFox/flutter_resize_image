// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Encode raw RGBA bytes to PNG using GDI+ (Windows)
/// This is 2-4x faster than SKIA's PNG encoder
Uint8List encodePngGdi(Uint8List rgbaBytes, int width, int height) {
  if (!io.Platform.isWindows) {
    throw UnsupportedError('GDI+ encoder is only available on Windows');
  }

  print('[GDI+] Starting PNG encoding for ${width}x$height image');

  // Initialize GDI+
  final token = calloc<IntPtr>();
  final input = calloc<GdiplusStartupInput>();
  input.ref.GdiplusVersion = 1;
  input.ref.DebugEventCallback = nullptr;
  input.ref.SuppressBackgroundThread = 0;
  input.ref.SuppressExternalCodecs = 0;

  print('[GDI+] Initializing GDI+...');
  var status = GdiplusStartup(token, input, nullptr);
  calloc.free(input);

  if (status != 0) {
    calloc.free(token);
    throw Exception('Failed to initialize GDI+: $status');
  }

  print('[GDI+] GDI+ initialized successfully');

  Pointer<IntPtr>? bitmap;
  Pointer<Uint8>? bgraBytes;

  try {
    print('[GDI+] Converting RGBA to BGRA...');
    // Convert RGBA to BGRA (GDI+ expects BGRA)
    // IMPORTANT: Don't free bgraBytes until after saving the image!
    // GdipCreateBitmapFromScan0 does not copy the data, it uses the pointer directly
    bgraBytes = calloc<Uint8>(rgbaBytes.length);
    for (var i = 0; i < rgbaBytes.length; i += 4) {
      bgraBytes[i] = rgbaBytes[i + 2]; // B
      bgraBytes[i + 1] = rgbaBytes[i + 1]; // G
      bgraBytes[i + 2] = rgbaBytes[i]; // R
      bgraBytes[i + 3] = rgbaBytes[i + 3]; // A
    }

    print('[GDI+] Creating bitmap...');
    // Create GDI+ bitmap from raw bytes
    final stride = width * 4;
    bitmap = calloc<IntPtr>();

    status = GdipCreateBitmapFromScan0(
      width,
      height,
      stride,
      PixelFormat32bppARGB,
      bgraBytes,
      bitmap,
    );

    print('[GDI+] GdipCreateBitmapFromScan0 status: $status');

    if (status != 0) {
      throw Exception('Failed to create bitmap: $status');
    }

    if (bitmap.value == 0) {
      throw Exception('Bitmap pointer is null');
    }

    print('[GDI+] Bitmap created successfully, handle: ${bitmap.value}');

    // PNG encoder CLSID: {557CF406-1A04-11D3-9A73-0000F81EF32E}
    print('[GDI+] Creating PNG CLSID...');
    final pngClsid = calloc<GUID>();
    pngClsid.ref.setGUID('{557CF406-1A04-11D3-9A73-0000F81EF32E}');

    try {
      // Save to temp file
      final tempPath =
          '${io.Directory.systemTemp.path}\\flutter_png_${DateTime.now().millisecondsSinceEpoch}.png';
      print('[GDI+] Temp file path: $tempPath');

      final pFilename = tempPath.toNativeUtf16();

      try {
        print('[GDI+] Calling GdipSaveImageToFile...');
        print('[GDI+] Parameters: image=${bitmap.value}, format=PNG');

        status = GdipSaveImageToFile(
          bitmap.value,
          pFilename,
          pngClsid,
          nullptr,
        );

        print('[GDI+] GdipSaveImageToFile status: $status');

        if (status != 0) {
          throw Exception('GdipSaveImageToFile failed with status: $status');
        }

        print('[GDI+] Checking if file exists...');
        // Read the file
        final file = io.File(tempPath);
        if (!file.existsSync()) {
          throw Exception('PNG file was not created at: $tempPath');
        }

        print('[GDI+] Reading file...');
        final result = file.readAsBytesSync();
        print('[GDI+] File read successfully, size: ${result.length} bytes');

        // Delete temp file
        try {
          file.deleteSync();
          print('[GDI+] Temp file deleted');
        } catch (e) {
          print('[GDI+] Warning: Could not delete temp file: $e');
        }

        return result;
      } finally {
        calloc.free(pFilename);
      }
    } finally {
      calloc.free(pngClsid);
    }
  } catch (e, st) {
    print('[GDI+] ERROR: $e');
    print('[GDI+] Stack trace: $st');
    rethrow;
  } finally {
    print('[GDI+] Cleanup...');

    // Free the BGRA bytes buffer
    if (bgraBytes != null) {
      print('[GDI+] Freeing BGRA buffer...');
      calloc.free(bgraBytes);
    }

    if (bitmap != null && bitmap.value != 0) {
      print('[GDI+] Disposing bitmap...');
      GdipDisposeImage(bitmap.value);
    }
    if (bitmap != null) {
      calloc.free(bitmap);
    }

    print('[GDI+] Shutting down GDI+...');
    GdiplusShutdown(token.value);
    calloc.free(token);
    print('[GDI+] Cleanup complete');
  }
}

// GDI+ FFI declarations
final _gdiplus = DynamicLibrary.open('gdiplus.dll');

// GdiplusStartup
typedef GdiplusStartup_Native =
    Int32 Function(
      Pointer<IntPtr> token,
      Pointer<GdiplusStartupInput> input,
      Pointer<Void> output,
    );
typedef GdiplusStartup_Dart =
    int Function(
      Pointer<IntPtr> token,
      Pointer<GdiplusStartupInput> input,
      Pointer<Void> output,
    );
final GdiplusStartup = _gdiplus
    .lookupFunction<GdiplusStartup_Native, GdiplusStartup_Dart>(
      'GdiplusStartup',
    );

// GdiplusShutdown
typedef GdiplusShutdown_Native = Void Function(IntPtr token);
typedef GdiplusShutdown_Dart = void Function(int token);
final GdiplusShutdown = _gdiplus
    .lookupFunction<GdiplusShutdown_Native, GdiplusShutdown_Dart>(
      'GdiplusShutdown',
    );

// GdipCreateBitmapFromScan0
typedef GdipCreateBitmapFromScan0_Native =
    Int32 Function(
      Int32 width,
      Int32 height,
      Int32 stride,
      Int32 format,
      Pointer<Uint8> scan0,
      Pointer<IntPtr> bitmap,
    );
typedef GdipCreateBitmapFromScan0_Dart =
    int Function(
      int width,
      int height,
      int stride,
      int format,
      Pointer<Uint8> scan0,
      Pointer<IntPtr> bitmap,
    );
final GdipCreateBitmapFromScan0 = _gdiplus
    .lookupFunction<
      GdipCreateBitmapFromScan0_Native,
      GdipCreateBitmapFromScan0_Dart
    >('GdipCreateBitmapFromScan0');

// GdipSaveImageToFile
typedef GdipSaveImageToFile_Native =
    Int32 Function(
      IntPtr image,
      Pointer<Utf16> filename,
      Pointer<GUID> clsidEncoder,
      Pointer<Void> encoderParams,
    );
typedef GdipSaveImageToFile_Dart =
    int Function(
      int image,
      Pointer<Utf16> filename,
      Pointer<GUID> clsidEncoder,
      Pointer<Void> encoderParams,
    );
final GdipSaveImageToFile = _gdiplus
    .lookupFunction<GdipSaveImageToFile_Native, GdipSaveImageToFile_Dart>(
      'GdipSaveImageToFile',
    );

// GdipDisposeImage
typedef GdipDisposeImage_Native = Int32 Function(IntPtr image);
typedef GdipDisposeImage_Dart = int Function(int image);
final GdipDisposeImage = _gdiplus
    .lookupFunction<GdipDisposeImage_Native, GdipDisposeImage_Dart>(
      'GdipDisposeImage',
    );

// GDI+ Structures
final class GdiplusStartupInput extends Struct {
  @Uint32()
  external int GdiplusVersion;

  external Pointer<Void> DebugEventCallback;

  @Int32()
  external int SuppressBackgroundThread;

  @Int32()
  external int SuppressExternalCodecs;
}

// Constants
const PixelFormat32bppARGB = 0x26200A;

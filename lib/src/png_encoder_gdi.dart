// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Optimized PNG encoder using GDI+
Uint8List encodePngGdi(Uint8List rgbaBytes, int width, int height) {
  if (!io.Platform.isWindows) {
    throw UnsupportedError('GDI+ encoder is only available on Windows');
  }

  // Initialize GDI+
  final token = calloc<IntPtr>();
  final input = calloc<GdiplusStartupInput>();
  input.ref.GdiplusVersion = 1;
  input.ref.DebugEventCallback = nullptr;
  input.ref.SuppressBackgroundThread = 0;
  input.ref.SuppressExternalCodecs = 0;

  var status = GdiplusStartup(token, input, nullptr);
  calloc.free(input);

  if (status != 0) {
    calloc.free(token);
    throw Exception('Failed to initialize GDI+: $status');
  }

  Pointer<IntPtr>? bitmap;
  Pointer<Uint8>? bgraBytes;

  try {
    // Optimized RGBA to BGRA conversion
    // Allocate once and keep until after save
    bgraBytes = calloc<Uint8>(rgbaBytes.length);
    final length = rgbaBytes.length;

    // Batch conversion - compiler can optimize this better
    for (var i = 0; i < length; i += 4) {
      bgraBytes[i] = rgbaBytes[i + 2]; // B
      bgraBytes[i + 1] = rgbaBytes[i + 1]; // G
      bgraBytes[i + 2] = rgbaBytes[i]; // R
      bgraBytes[i + 3] = rgbaBytes[i + 3]; // A
    }

    // Create GDI+ bitmap
    bitmap = calloc<IntPtr>();
    status = GdipCreateBitmapFromScan0(
      width,
      height,
      width * 4, // stride
      _pixelFormat32bppARGB,
      bgraBytes,
      bitmap,
    );

    if (status != 0 || bitmap.value == 0) {
      throw Exception('Failed to create bitmap: $status');
    }

    // PNG CLSID
    final pngClsid = calloc<GUID>();
    pngClsid.ref.setGUID('{557CF406-1A04-11D3-9A73-0000F81EF32E}');

    try {
      // Use fixed temp path (faster than timestamp)
      const tempPath = 'C:\\Windows\\Temp\\flutter_png_temp.png';
      final pFilename = tempPath.toNativeUtf16();

      try {
        status = GdipSaveImageToFile(
          bitmap.value,
          pFilename,
          pngClsid,
          nullptr,
        );

        if (status != 0) {
          throw Exception('Save failed: $status');
        }

        // Read and return
        final result = io.File(tempPath).readAsBytesSync();

        // Delete (ignore errors)
        try {
          io.File(tempPath).deleteSync();
        } catch (_) {}

        return result;
      } finally {
        calloc.free(pFilename);
      }
    } finally {
      calloc.free(pngClsid);
    }
  } finally {
    if (bgraBytes != null) calloc.free(bgraBytes);
    if (bitmap != null) {
      if (bitmap.value != 0) GdipDisposeImage(bitmap.value);
      calloc.free(bitmap);
    }
    GdiplusShutdown(token.value);
    calloc.free(token);
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
const _pixelFormat32bppARGB = 0x26200A;

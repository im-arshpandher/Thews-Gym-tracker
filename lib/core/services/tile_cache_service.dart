import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persistent Disk Tile Provider for Leaflet OpenStreetMap in flutter_map.
/// Safely caches fetched tile PNGs permanently to local device storage with
/// atomic file writes, PNG signature validation, and corrupted file auto-recovery.
class PersistentDiskTileProvider extends TileProvider {
  PersistentDiskTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    final tileKey = '${coordinates.z}_${coordinates.x}_${coordinates.y}';
    return DiskCachedTileImageProvider(url, tileKey);
  }
}

class DiskCachedTileImageProvider
    extends ImageProvider<DiskCachedTileImageProvider> {
  final String url;
  final String tileKey;
  static String? _cacheDirPath;

  DiskCachedTileImageProvider(this.url, this.tileKey);

  static Future<void> ensureCacheDir() async {
    if (_cacheDirPath == null) {
      try {
        final dir = await getApplicationSupportDirectory();
        final cacheDir = Directory(p.join(dir.path, 'map_tiles_cache'));
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }
        _cacheDirPath = cacheDir.path;
      } catch (_) {}
    }
  }

  static Future<double> getCacheSizeMegaBytes() async {
    await ensureCacheDir();
    if (_cacheDirPath == null) return 0.0;
    final dir = Directory(_cacheDirPath!);
    if (!await dir.exists()) return 0.0;

    int totalBytes = 0;
    await for (final file in dir.list(recursive: false, followLinks: false)) {
      if (file is File) {
        totalBytes += await file.length();
      }
    }
    return totalBytes / (1024 * 1024);
  }

  static Future<void> clearMapCache() async {
    await ensureCacheDir();
    if (_cacheDirPath == null) return;
    final dir = Directory(_cacheDirPath!);
    if (await dir.exists()) {
      await for (final file in dir.list(recursive: false, followLinks: false)) {
        if (file is File) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }
  }

  /// Check if file contains valid PNG image magic bytes
  static bool _isValidPng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  @override
  Future<DiskCachedTileImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<DiskCachedTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    DiskCachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('URL', this);
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    DiskCachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    await ensureCacheDir();

    if (_cacheDirPath != null) {
      final sanitizeKey = tileKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final filePath = p.join(_cacheDirPath!, '$sanitizeKey.png');
      final tempFilePath = p.join(_cacheDirPath!, '$sanitizeKey.tmp');
      final file = File(filePath);

      // 1. Read from persistent local disk cache with validation
      try {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (_isValidPng(bytes)) {
            final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
            return decode(buffer);
          } else {
            // Corrupted or truncated file: safely delete and re-fetch
            await file.delete();
          }
        }
      } catch (_) {}

      // 2. Fetch over HTTP and perform atomic file write to prevent corruption
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: const {'User-Agent': 'com.thews.gymtracker'},
        );
        if (response.statusCode == 200 &&
            response.bodyBytes.isNotEmpty &&
            _isValidPng(response.bodyBytes)) {
          try {
            final tempFile = File(tempFilePath);
            await tempFile.writeAsBytes(response.bodyBytes, flush: true);
            await tempFile.rename(filePath);
          } catch (_) {
            // Fallback direct write if atomic rename is restricted
            await file.writeAsBytes(response.bodyBytes, flush: true);
          }
          final buffer =
              await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
          return decode(buffer);
        }
      } catch (_) {}
    }

    // 1x1 Transparent Fallback Image if offline and not cached
    final transparentBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
    final buffer = await ui.ImmutableBuffer.fromUint8List(transparentBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is DiskCachedTileImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

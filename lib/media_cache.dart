import 'dart:io';

import 'package:ftpconnect/ftpConnect.dart';

import 'types/config.dart';

// Process-wide caches of downloaded media. Keyed by a stable identity
// (host/port/cwd/name/size/mtime). Survive viewer pop and are consulted by
// the download flow so user-initiated downloads don't refetch already-cached
// files.
final Map<String, File> imageFileCache = {};
final Map<String, File> videoCache = {};

String mediaCacheKey(Config c, String wd, FTPEntry e) =>
    '${c.host}|${c.port}|$wd|${e.name}|${e.size ?? 0}|${e.modifyTime?.millisecondsSinceEpoch ?? 0}';

/// Look up a cached file across both caches. Returns null if absent or if the
/// backing temp file has been wiped by the OS — and in that case removes the
/// stale entry.
File? findCachedMedia(Config c, String wd, FTPEntry e) {
  final key = mediaCacheKey(c, wd, e);
  for (final cache in [imageFileCache, videoCache]) {
    final f = cache[key];
    if (f == null) continue;
    if (f.existsSync()) return f;
    cache.remove(key);
  }
  return null;
}

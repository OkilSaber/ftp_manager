import 'dart:async';

import 'package:ftpconnect/ftpConnect.dart';

import 'types/config.dart';

/// Pool of FTPConnect instances, each connected, in binary mode, and `cwd` to
/// [workingDirectory]. Acquires up to [maxSize] connections lazily — connection
/// N is only opened when there are N concurrent requests.
class FtpPool {
  final Config config;
  final String workingDirectory;
  final int maxSize;

  final List<_PoolEntry> _entries = [];
  final List<Completer<FTPConnect>> _waiters = [];
  bool _disposed = false;

  FtpPool({
    required this.config,
    required this.workingDirectory,
    this.maxSize = 5,
  });

  Future<T> withConnection<T>(
    Future<T> Function(FTPConnect) action, {
    int retries = 2,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (int attempt = 0; attempt <= retries; attempt++) {
      FTPConnect? conn;
      try {
        conn = await _acquire();
        final result = await action(conn);
        _release(conn);
        return result;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        if (conn != null) {
          // Connection may be in a bad state (timeout, broken control
          // socket, server-side PASV bind failure leaving us out of sync).
          // Drop it so the next attempt opens a fresh one.
          _discard(conn);
        }
        if (!_isRecoverable(e) || attempt == retries) {
          Error.throwWithStackTrace(e, st);
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  bool _isRecoverable(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('passive mode') ||
        msg.contains('timeout') ||
        msg.contains('broken pipe') ||
        msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('425') ||
        msg.contains('421') ||
        msg.contains('illegal reply');
  }

  void _discard(FTPConnect conn) {
    _entries.removeWhere((e) => identical(e.conn, conn));
    conn.disconnect().catchError((_) => false);
  }

  Future<FTPConnect> _acquire() async {
    if (_disposed) throw StateError('FtpPool disposed');
    for (final e in _entries) {
      final conn = e.conn;
      if (!e.busy && conn != null) {
        e.busy = true;
        return conn;
      }
    }
    if (_entries.length < maxSize) {
      final placeholder = _PoolEntry.pending();
      _entries.add(placeholder);
      try {
        final conn = await _create();
        if (_disposed) {
          await conn.disconnect().catchError((_) => false);
          throw StateError('FtpPool disposed');
        }
        placeholder.conn = conn;
        placeholder.busy = true;
        return conn;
      } catch (e) {
        _entries.remove(placeholder);
        // Wake one waiter so it can retry / resize.
        if (_waiters.isNotEmpty) {
          _waiters.removeAt(0).completeError(e);
        }
        rethrow;
      }
    }
    final waiter = Completer<FTPConnect>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release(FTPConnect conn) {
    final entry = _entries.firstWhere(
      (e) => identical(e.conn, conn),
      orElse: () => _PoolEntry.missing(),
    );
    if (entry.isMissing) return;
    if (_disposed) {
      _entries.remove(entry);
      conn.disconnect().catchError((_) => false);
      return;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(conn);
    } else {
      entry.busy = false;
    }
  }

  Future<FTPConnect> _create() async {
    final c = FTPConnect(
      config.host,
      user: config.username,
      pass: config.password,
      port: config.port,
      timeout: 20,
    );
    await c.connect();
    await c.setTransferType(TransferType.binary);
    if (workingDirectory.isNotEmpty && workingDirectory != '/') {
      await c.changeDirectory(workingDirectory);
    }
    return c;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final entries = _entries.toList();
    _entries.clear();
    for (final w in _waiters) {
      w.completeError(StateError('FtpPool disposed'));
    }
    _waiters.clear();
    for (final e in entries) {
      final c = e.conn;
      if (c != null) {
        await c.disconnect().catchError((_) => false);
      }
    }
  }
}

class _PoolEntry {
  FTPConnect? conn;
  bool busy;
  final bool isMissing;

  _PoolEntry.pending()
      : conn = null,
        busy = true,
        isMissing = false;

  _PoolEntry.missing()
      : conn = null,
        busy = false,
        isMissing = true;
}

import 'telemetry_model.dart';

const _accessScope = 'dart_orpc.access';
const _serverScope = 'dart_orpc.server';
const _serverStarted = 'server.started';
const _serverStopped = 'server.stopped';
const _urlPrefix = 'url.';
const _serviceName = 'service.name';
const _maxStackFrames = 12;
const _slowSeconds = 0.1;
const _verySlowSeconds = 1.0;
const _pathWidth = 16;
const _rpcMethodWidth = 16;

const _reset = '\x1B[0m';
const _bold = '1';
const _red = '31';
const _green = '32';
const _yellow = '33';
const _blue = '34';
const _magenta = '35';
const _cyan = '36';
const _grey = '90';

/// Formats log records for people reading a terminal during development.
final class RpcPrettyFormat {
  const RpcPrettyFormat({required this.colors});

  final bool colors;

  void write(StringBuffer out, RpcLogRecord record) {
    switch (record) {
      case RpcLogRecord(scope: _serverScope, message: _serverStarted):
        _writeStartBanner(out, record);
      case RpcLogRecord(scope: _serverScope, message: _serverStopped):
        _writeLine(out, record, [
          _paint('${record.attributes[_serviceName]} stopped', _bold),
        ]);
      case RpcLogRecord(scope: _accessScope):
        _writeLine(out, record, _accessColumns(record));
      case _:
        _writeLine(out, record, _recordColumns(record));
    }
    _writeStackTrace(out, record.stackTrace);
  }

  void _writeLine(StringBuffer out, RpcLogRecord record, List<String> columns) {
    out
      ..write(_paint(_clock(record.timestamp), _grey))
      ..write('  ')
      ..write(_level(record.severity))
      ..write('  ')
      ..write(columns.where((column) => column.isNotEmpty).join('  '));
    if (record.traceId case final traceId?) {
      out.write('  ${_paint(traceId.substring(0, 8), _grey)}');
    }
    out.writeln();
  }

  List<String> _accessColumns(RpcLogRecord record) {
    final attributes = record.attributes;
    final webSocket = attributes['network.transport'] == 'websocket';
    final method = webSocket ? 'WS' : '${attributes['http.request.method']}';
    final status = attributes['http.response.status_code'];
    final seconds = attributes['http.server.request.duration'];
    return [
      _paint(method.padRight(6), _methodColour(method)),
      '${attributes['url.path']}'.padRight(_pathWidth),
      _paint(
        switch (attributes['rpc.method']) {
          final String rpcMethod => rpcMethod,
          _ => '',
        }.padRight(_rpcMethodWidth),
        _bold,
      ),
      switch (status) {
        final int code => _paint('$code', _statusColour(code)),
        _ => _webSocketOutcome(record),
      },
      if (seconds case final double value) _duration(value),
      if (attributes['error.type'] case final String errorType)
        _paint(errorType, _statusColour(status is int ? status : 500)),
    ];
  }

  String _webSocketOutcome(RpcLogRecord record) => switch (record.severity) {
    RpcLogSeverity.error => _paint('failed', _red),
    RpcLogSeverity.warn => _paint('rejected', _yellow),
    _ => _paint('ok', _green),
  };

  List<String> _recordColumns(RpcLogRecord record) => [
    _paint(record.scope, _cyan),
    _paint(
      record.message,
      record.severity.isAtLeast(RpcLogSeverity.warn) ? _bold : '',
    ),
    for (final MapEntry(:key, :value) in record.attributes.entries)
      if (value != null) '${_paint('$key=', _grey)}${_value(value)}',
  ];

  void _writeStartBanner(StringBuffer out, RpcLogRecord record) {
    final urls = [
      for (final MapEntry(:key, :value) in record.attributes.entries)
        if (key.startsWith(_urlPrefix))
          (key.substring(_urlPrefix.length), '$value'),
    ];
    final width = urls.fold(0, (widest, url) {
      return url.$1.length > widest ? url.$1.length : widest;
    });
    out
      ..writeln()
      ..writeln(
        '  ${_paint('dart_orpc', '$_bold;$_magenta')}  '
        '${_paint('${record.attributes[_serviceName]}', _bold)} is listening',
      )
      ..writeln();
    for (final (name, url) in urls) {
      out.writeln(
        '  ${_paint('➜', _green)}  ${_paint(name.padRight(width), _grey)}  '
        '${_paint(url, _cyan)}',
      );
    }
    out.writeln();
  }

  void _writeStackTrace(StringBuffer out, StackTrace? stackTrace) {
    if (stackTrace == null) {
      return;
    }
    final frames = stackTrace.toString().trimRight().split('\n');
    for (final frame in frames.take(_maxStackFrames)) {
      out.writeln(_paint('    ${frame.trim()}', _grey));
    }
    if (frames.length > _maxStackFrames) {
      out.writeln(
        _paint('    … ${frames.length - _maxStackFrames} more frames', _grey),
      );
    }
  }

  String _level(RpcLogSeverity severity) {
    final label = severity.label.padRight(5);
    return switch (severity) {
      RpcLogSeverity.trace || RpcLogSeverity.debug => _paint(label, _grey),
      RpcLogSeverity.info => _paint(label, _green),
      RpcLogSeverity.warn => _paint(label, '$_bold;$_yellow'),
      RpcLogSeverity.error ||
      RpcLogSeverity.fatal => _paint(label, '$_bold;$_red'),
    };
  }

  String _duration(double seconds) {
    final text = seconds < 1
        ? '${(seconds * 1000).toStringAsFixed(1)} ms'
        : '${seconds.toStringAsFixed(2)} s';
    final colour = seconds >= _verySlowSeconds
        ? _red
        : seconds >= _slowSeconds
        ? _yellow
        : _grey;
    return _paint(text.padLeft(9), colour);
  }

  String _methodColour(String method) => switch (method) {
    'GET' => _blue,
    'POST' => _green,
    'PUT' || 'PATCH' => _yellow,
    'DELETE' => _red,
    'WS' => _magenta,
    _ => _grey,
  };

  String _statusColour(int status) => switch (status) {
    >= 500 => '$_bold;$_red',
    >= 400 => _yellow,
    >= 300 => _cyan,
    _ => _green,
  };

  String _value(Object value) => switch (value) {
    Iterable() => '[${value.join(', ')}]',
    _ => '$value',
  };

  String _clock(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.'
        '${local.millisecond.toString().padLeft(3, '0')}';
  }

  String _paint(String text, String style) =>
      colors && style.isNotEmpty ? '\x1B[${style}m$text$_reset' : text;
}

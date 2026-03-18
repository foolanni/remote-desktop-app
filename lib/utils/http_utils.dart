import 'dart:convert';
import 'dart:io';

export 'dart:convert' show utf8, jsonDecode;

// Re-export HttpClient for punk_setup_screen
class ContentType {
  static final json = ContentType._('application/json');
  final String mimeType;
  ContentType._(this.mimeType);
}

class HttpClient extends dart_io.HttpClient {
  HttpClient() : super();
}

// ignore: library_prefixes
import 'dart:io' as dart_io;

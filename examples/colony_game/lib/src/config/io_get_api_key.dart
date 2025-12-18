import 'dart:io';

String? getApiKey() {
  return Platform.environment['GEMINI_API_KEY'];
}

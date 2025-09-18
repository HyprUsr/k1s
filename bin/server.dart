import 'dart:io';

import 'package:k1s/http.dart';
import 'package:k1s/job_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:toml/toml.dart';

void main(List<String> args) async {
  int port = 1298;
  String authToken = 'abc123'; // Default token, should be overridden by config file

  int configIndex = args.indexOf('-c');
  if (configIndex != -1 && configIndex + 1 < args.length) {
    final configPath = args[configIndex + 1];
    if (!File(configPath).existsSync()) {
      print('Config file not found: $configPath');
      exit(1);
    }
    final document = await TomlDocument.load(configPath);
    final toml = document.toMap();
    if (toml.containsKey('http')) {
      final serverConfig = toml['http'];
      if (serverConfig is Map<String, dynamic>) {
        if (serverConfig.containsKey('port')) {
          port = serverConfig['port'] as int;
        }
        if (serverConfig.containsKey('auth_token')) {
          authToken = serverConfig['auth_token'] as String;
        }
      }
    }
  }

  final jobManager = JobManager();

  final router = Http(jobManager).router;

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(authenticateRequests(token: authToken))
      .addHandler(router.call);

  // For running in containers, we respect the PORT environment variable.
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}

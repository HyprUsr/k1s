import 'dart:convert';
import 'dart:io';

import 'package:k1s/server/command_processor.dart';
import 'package:k1s/server/job_manager.dart';
import 'package:toml/toml.dart';

void main(List<String> args) async {
  int port = 4567;

  int configIndex = args.indexOf('-c');
  if (configIndex != -1 && configIndex + 1 < args.length) {
    final configPath = args[configIndex + 1];
    if (!File(configPath).existsSync()) {
      print('Config file not found: $configPath');
      exit(1);
    }
    final document = await TomlDocument.load(configPath);
    final toml = document.toMap();
    if (toml.containsKey('server')) {
      final serverConfig = toml['server'];
      if (serverConfig is Map<String, dynamic>) {
        if (serverConfig.containsKey('port')) {
          port = serverConfig['port'] as int;
        }
      }
    }
  }

  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
  print('Server listening on port ${server.port}');

  final jobManager = JobManager();

  await for (final socket in server) {
    final commandProcessor = CommandProcessor(
      jobManager,
      (message) => socket.write(message),
    );
    socket.listen((data) async {
      try {
        await commandProcessor.process(utf8.decode(data).trim());
        socket.write('Command processed successfully.\n');
      } catch (e) {
        socket.write('Error processing command!\n');
        print('Error processing command: $e');
      } finally {
        socket.close();
      }
    });
  }
}

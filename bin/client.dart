import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:k1s/commands.dart';
import 'package:k1s/server/job.dart';

void main(List<String> arguments) async {
  var parser = ArgParser();
  parser.addOption('port', abbr: 'p', defaultsTo: '4567', help: 'Server port');
  parser.addOption(
    'host',
    abbr: 'h',
    defaultsTo: '127.0.0.1',
    help: 'Server host',
  );
  parser.addOption(
    'command',
    abbr: 'c',
    help: 'Command to execute',
    mandatory: true,
    allowed: ClientCommand.values.map((e) => e.command).toList(),
  );
  parser.addOption('id', abbr: 'i', help: 'Job ID');
  parser.addOption(
    'type',
    abbr: 't',
    help: 'Job type',
    allowed: JobType.values.map((e) => e.type).toList(),
  );
  parser.addOption('executable', abbr: 'x', help: 'Executable path');
  parser.addOption('arguments', abbr: 'a', help: 'Executable arguments');
  parser.addOption('workingDirectory', abbr: 'w', help: 'Working directory');
  parser.addMultiOption(
    'environment',
    abbr: 'e',
    help: 'Environment variables',
  );
  parser.addOption('period', abbr: 'r', help: 'Job period in seconds');
  var args = parser.parse(arguments);

  final commandType = ClientCommand.fromCommand(args.option('command'));
  if (commandType == null) {
    print('Unknown command: ${args.option('command')}');
    exit(1);
  }

  Command command;
  switch (commandType) {
    case ClientCommand.getAllJobs:
      command = GetAllJobsCommand();
      break;
    case ClientCommand.getJobById:
      final jobId = args.option('id');
      if (jobId == null) {
        print('Job ID is required for get-job-by-id command');
        exit(1);
      }
      command = GetJobByIdCommand(jobId: jobId);
      break;
    case ClientCommand.createJob:
      final jobId = args.option('id');
      final jobType = JobType.fromType(args.option('type'));
      final executable = args.option('executable');
      final argumentsStr = args.option('arguments') ?? '';
      final workingDirectory = args.option('workingDirectory');
      final environmentList = args.multiOption('environment');
      final periodStr = args.option('period');
      if (jobId == null || jobType == null || executable == null) {
        print('Job ID, type, and executable are required.');
        exit(1);
      }
      final arguments = argumentsStr.split(' ');
      final environment = <String, String>{};
      for (var env in environmentList) {
        final parts = env.split('=');
        if (parts.length == 2) {
          environment[parts[0]] = parts[1];
        } else {
          print('Invalid environment variable format: $env');
          exit(1);
        }
      }
      int? periodSeconds;
      if (jobType == JobType.periodic) {
        if (periodStr == null) {
          print('Period is required for periodic job');
          exit(1);
        }
        periodSeconds = int.tryParse(periodStr);
        if (periodSeconds == null || periodSeconds <= 0) {
          print('Invalid period: $periodStr');
          exit(1);
        }
      }

      command = CreateJobCommand(
        id: jobId,
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        jobType: jobType,
        periodInSeconds: periodSeconds,
      );
      break;
    case ClientCommand.killJob:
      final jobId = args.option('id');
      if (jobId == null) {
        print('Job ID is required for kill-job command');
        exit(1);
      }
      command = KillJobCommand(jobId: jobId, signal: 'sigint');
      break;
    case ClientCommand.deleteJob:
      final jobId = args.option('id');
      if (jobId == null) {
        print('Job ID is required for delete-job command');
        exit(1);
      }
      command = DeleteJobCommand(jobId: jobId);
      break;
  }

  try {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, 4567);
    socket.write('${jsonEncode(command.toJson())}\n');
    await socket.flush();

    // Optionally, read the response from the server
    await for (var data in socket) {
      print('Server response: ${utf8.decode(data)}');
    }
    await socket.close();
  } catch (e) {
    print('Error connecting to the server: $e');
  }
}

enum ClientCommand {
  getAllJobs('get-all-jobs'),
  getJobById('get-job-by-id'),
  createJob('create-job'),
  killJob('kill-job'),
  deleteJob('delete-job');

  final String command;
  const ClientCommand(this.command);

  static ClientCommand? fromCommand(String? command) {
    return ClientCommand.values.where((e) => e.command == command).firstOrNull;
  }
}

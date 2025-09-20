import 'package:k1s/job.dart';

abstract class Command {
  final ClientCommand command;
  Command({required this.command});

  Map<String, dynamic> toJson();

  static Command fromJson(Map<String, dynamic> json) {
    final commandStr = json['command'];
    if (commandStr == null) {
      throw ArgumentError('Invalid command JSON: missing "command" field');
    }

    final command = ClientCommand.values.firstWhere(
      (c) => c.name == commandStr,
      orElse: () => throw ArgumentError('Unknown command: $commandStr'),
    );

    switch (command) {
      case ClientCommand.getAllJobs:
        return GetAllJobsCommand();
      case ClientCommand.getJobById:
        final jobId = json['jobId'];
        if (jobId == null) {
          throw ArgumentError(
            'Invalid GetJobByIdCommand JSON: missing "jobId" field',
          );
        }
        return GetJobByIdCommand(jobId: jobId);
      case ClientCommand.createJob:
        final jobData = json['job'];
        if (jobData == null || jobData is! Map<String, dynamic>) {
          throw ArgumentError(
            'Invalid CreateJobCommand JSON: missing or invalid "job" field',
          );
        }
        return CreateJobCommand(
          id: jobData['id'],
          executable: jobData['executable'],
          arguments: List<String>.from(jobData['arguments'] ?? []),
          workingDirectory: jobData['workingDirectory'] ?? '',
          environment: Map<String, String>.from(jobData['environment'] ?? {}),
          jobType:
              JobType.fromType(jobData['type']) ??
              (throw ArgumentError('Invalid or missing job type')),
          maxRetry: jobData['maxRetry'],
          periodInSeconds: jobData['periodInSeconds'],
          stdoutLogPath: jobData['stdoutLogPath'],
          stderrLogPath: jobData['stderrLogPath'],
          errorLogPath: jobData['errorLogPath'],
        );
      case ClientCommand.killJob:
        final jobId = json['jobId'];
        if (jobId == null) {
          throw ArgumentError(
            'Invalid KillJobCommand JSON: missing "jobId" field',
          );
        }
        return KillJobCommand(jobId: jobId, signal: json['signal'] ?? 'sigint');
      case ClientCommand.deleteJob:
        final jobId = json['jobId'];
        if (jobId == null) {
          throw ArgumentError(
            'Invalid DeleteJobCommand JSON: missing "jobId" field',
          );
        }
        return DeleteJobCommand(jobId: jobId);
    }
  }
}

final class GetAllJobsCommand extends Command {
  GetAllJobsCommand() : super(command: ClientCommand.getAllJobs);

  @override
  Map<String, dynamic> toJson() {
    return {'command': command.name};
  }
}

final class GetJobByIdCommand extends Command {
  final String jobId;
  GetJobByIdCommand({required this.jobId})
    : super(command: ClientCommand.getJobById);

  @override
  Map<String, dynamic> toJson() {
    return {'command': command.name, 'jobId': jobId};
  }
}

final class CreateJobCommand extends Command {
  final String id;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final JobType jobType;
  final int? periodInSeconds;
  final int? maxRetry;
  final String? stdoutLogPath;
  final String? stderrLogPath;
  final String? errorLogPath;

  CreateJobCommand({
    required this.id,
    required this.jobType,
    required this.executable,
    this.arguments = const [],
    this.workingDirectory = '',
    this.environment = const {},
    this.periodInSeconds,
    this.maxRetry,
    this.stdoutLogPath,
    this.stderrLogPath,
    this.errorLogPath,
  }) : super(command: ClientCommand.createJob);

  @override
  Map<String, dynamic> toJson() {
    return {
      'command': command.name,
      'job': {
        'id': id,
        'executable': executable,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
        'environment': environment,
        'periodInSeconds': periodInSeconds,
        'maxRetry': maxRetry,
        'type': jobType.type,
        'stdoutLogPath': stdoutLogPath,
        'stderrLogPath': stderrLogPath,
        'errorLogPath': errorLogPath,
      },
    };
  }
}

final class KillJobCommand extends Command {
  final String jobId;
  final String signal;

  KillJobCommand({required this.jobId, this.signal = 'sigint'})
    : super(command: ClientCommand.killJob);

  @override
  Map<String, dynamic> toJson() {
    return {'command': command.name, 'jobId': jobId, 'signal': signal};
  }
}

final class DeleteJobCommand extends Command {
  final String jobId;

  DeleteJobCommand({required this.jobId})
    : super(command: ClientCommand.deleteJob);

  @override
  Map<String, dynamic> toJson() {
    return {'command': command.name, 'jobId': jobId};
  }
}

enum ClientCommand {
  getAllJobs,
  getJobById,
  createJob,
  killJob,
  deleteJob;

  static ClientCommand? fromName(String command) {
    return ClientCommand.values.where((e) => e.name == command).firstOrNull;
  }
}

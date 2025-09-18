import 'dart:async';
import 'dart:io';

abstract class Job {
  final String id;
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;
  Process? process;
  List<JobResult> results = [];

  Job({
    required this.id,
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
  });

  Map<String, dynamic> toJson();
}

class ContinuousJob extends Job {
  bool restartOnFailure;
  bool _killRequested = false;
  ContinuousJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
    this.restartOnFailure = true,
  });

  void kill({ProcessSignal signal = ProcessSignal.sigint}) {
    _killRequested = true;
    process?.kill(signal);
  }

  bool get killRequested => _killRequested;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'executable': executable,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'environment': environment,
      'restartOnFailure': restartOnFailure,
      'killRequested': killRequested,
      'results': results
          .map(
            (result) => {
              'exitCode': result.exitCode,
              'stdout': result.stdout,
              'stderr': result.stderr,
            },
          )
          .toList(),
    };
  }
}

class OneOffJob extends Job {
  OneOffJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'executable': executable,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'environment': environment,
      'results': results
          .map(
            (result) => {
              'exitCode': result.exitCode,
              'stdout': result.stdout,
              'stderr': result.stderr,
            },
          )
          .toList(),
    };
  }
}

class CronJob extends Job {
  final Duration schedule;
  bool _killRequested = false;
  Timer? timer;

  CronJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
    required this.schedule,
  });

  void kill({ProcessSignal signal = ProcessSignal.sigint}) {
    _killRequested = true;
    process?.kill(signal);
    timer?.cancel();
  }

  bool get killRequested => _killRequested;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'executable': executable,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'environment': environment,
      'schedule': schedule.inSeconds,
      'killRequested': killRequested,
      'results': results
          .map(
            (result) => {
              'exitCode': result.exitCode,
              'stdout': result.stdout,
              'stderr': result.stderr,
            },
          )
          .toList(),
    };
  }
}

final class JobResult {
  int? exitCode;
  String stdout;
  String stderr;

  JobResult({this.exitCode, this.stdout = '', this.stderr = ''});
}

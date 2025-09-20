import 'dart:async';
import 'dart:io';

abstract class Job {
  final JobType jobType;
  final String id;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  Process? process;
  List<JobResult> results = [];

  Job({
    required this.jobType,
    required this.id,
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
  });

  Map<String, dynamic> toJson();
}

class ContinuousJob extends Job {
  static const int maxFailedCount = 5;

  bool restartOnFailure;
  bool _killRequested = false;
  int failedCount = 0;

  ContinuousJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
    this.restartOnFailure = true,
  }) : super(jobType: JobType.continuous);

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
      'results': results
          .map(
            (result) => {
              'exitCode': result.exitCode,
              'stdout': result.stdout,
              'stderr': result.stderr,
              'error': result.error,
            },
          )
          .toList(),
    };
  }
}

class OneTimeJob extends Job {
  OneTimeJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
  }) : super(jobType: JobType.oneTime);

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
              'error': result.error,
            },
          )
          .toList(),
    };
  }
}

class PeriodicJob extends Job {
  final Duration period;
  bool _killRequested = false;
  Timer? timer;

  PeriodicJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
    required this.period,
  }) : super(jobType: JobType.periodic);

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
      'periodInSeconds': period.inSeconds,
      'killRequested': killRequested,
      'results': results
          .map(
            (result) => {
              'exitCode': result.exitCode,
              'stdout': result.stdout,
              'stderr': result.stderr,
              'error': result.error,
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
  String error;

  JobResult({
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.error = '',
  });
}

enum JobType {
  continuous('continuous'),
  oneTime('one-time'),
  periodic('periodic');

  final String type;

  const JobType(this.type);

  static JobType? fromType(String? type) {
    return JobType.values.where((e) => e.type == type).firstOrNull;
  }
}

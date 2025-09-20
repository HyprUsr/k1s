import 'dart:async';
import 'dart:io';

abstract class Job {
  bool _killRequested = false;
  final JobType jobType;
  final String id;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  Process? process;
  final String? stdoutLogPath;
  final String? stderrLogPath;
  final String? errorLogPath;

  Job({
    required this.jobType,
    required this.id,
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    this.stdoutLogPath,
    this.stderrLogPath,
    this.errorLogPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': jobType.type,
      'executable': executable,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'environment': environment,
      'stdoutLogPath': stdoutLogPath,
      'stderrLogPath': stderrLogPath,
      'errorLogPath': errorLogPath,
    };
  }

  void kill({ProcessSignal signal = ProcessSignal.sigint}) {
    _killRequested = true;
    process?.kill(signal);
  }

  bool get killRequested => _killRequested;
}

class ContinuousJob extends Job {
  int maxRetry;
  int failedCount = 0;

  ContinuousJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
    super.stdoutLogPath,
    super.stderrLogPath,
    super.errorLogPath,
    this.maxRetry = 5,
  }) : super(jobType: JobType.continuous);

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'failedCount': failedCount,
      'maxRetry': maxRetry,
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
    super.stdoutLogPath,
    super.stderrLogPath,
    super.errorLogPath,
  }) : super(jobType: JobType.oneTime);
}

class PeriodicJob extends Job {
  final Duration period;
  Timer? timer;
  int maxRetry;
  int failedCount = 0;

  PeriodicJob({
    required super.id,
    required super.executable,
    required super.arguments,
    required super.workingDirectory,
    required super.environment,
    required this.period,
    this.maxRetry = 5,
    super.stdoutLogPath,
    super.stderrLogPath,
    super.errorLogPath,
  }) : super(jobType: JobType.periodic);

  @override
  void kill({ProcessSignal signal = ProcessSignal.sigint}) {
    _killRequested = true;
    process?.kill(signal);
    timer?.cancel();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'periodInSeconds': period.inSeconds,
      'failedCount': failedCount,
      'maxRetry': maxRetry,
    };
  }
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

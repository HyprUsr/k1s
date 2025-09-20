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

  Map<String, dynamic> toJson();
}

class ContinuousJob extends Job {
  static const int maxFailedCount = 5;

  bool _killRequested = false;
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
      'stdoutLogPath': stdoutLogPath,
      'stderrLogPath': stderrLogPath,
      'errorLogPath': errorLogPath,
      'failedCount': failedCount,
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

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'executable': executable,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'environment': environment,
      'stdoutLogPath': stdoutLogPath,
      'stderrLogPath': stderrLogPath,
      'errorLogPath': errorLogPath,
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
      'stdoutLogPath': stdoutLogPath,
      'stderrLogPath': stderrLogPath,
      'errorLogPath': errorLogPath,
      'periodInSeconds': period.inSeconds,
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

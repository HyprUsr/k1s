import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:k1s/job.dart';

class JobManager {
  final Map<String, Job> _jobs = {};

  void addJob(Job job) {
    _jobs[job.id] = job;
    _processJob(job);
  }

  void removeJob(Job job) {
    _jobs.remove(job.id);
    job.kill();
  }

  Map<String, Job> get jobs => Map.unmodifiable(_jobs);

  Future<void> _processJob(Job job) async {
    final stdoutFile = File(job.stdoutLogPath ?? 'stdout_${job.id}.log');
    final stderrFile = File(job.stderrLogPath ?? 'stderr_${job.id}.log');
    final errorLogFile = File(job.errorLogPath ?? 'error_${job.id}.log');
    if (job is ContinuousJob) {
      while (job.killRequested == false &&
          (job.maxRetry == -1 || job.failedCount < job.maxRetry)) {
        try {
          await executeFunction(job, stdoutFile, stderrFile);
        } catch (e) {
          job.failedCount += 1;
          errorLogFile.writeAsStringSync(
            '[${job.id}]: $e${Platform.lineTerminator}',
            mode: FileMode.append,
            flush: true,
          );
        }
      }
    } else if (job is OneTimeJob) {
      try {
        await executeFunction(job, stdoutFile, stderrFile);
      } catch (e) {
        errorLogFile.writeAsStringSync(
          '[${job.id}]: $e${Platform.lineTerminator}',
          mode: FileMode.append,
          flush: true,
        );
      }
    } else if (job is PeriodicJob) {
      job.timer = Timer.periodic(job.period, (timer) async {
        if (job.killRequested) {
          timer.cancel();
          return;
        }
        try {
          await executeFunction(job, stdoutFile, stderrFile);
        } catch (e) {
          errorLogFile.writeAsStringSync(
            '[${job.id}]: $e${Platform.lineTerminator}',
            mode: FileMode.append,
            flush: true,
          );
          job.failedCount += 1;
          if (job.maxRetry != -1 && job.failedCount >= job.maxRetry) {
            timer.cancel();
          }
        }
      });
    }
  }

  Future<void> executeFunction(
    Job job,
    File stdoutFile,
    File stderrFile,
  ) async {
    job.process = await Process.start(
      job.executable,
      job.arguments,
      workingDirectory: job.workingDirectory,
      environment: job.environment,
      includeParentEnvironment: false,
    );

    // Listen to the process's stdout stream
    job.process!.stdout.transform(utf8.decoder).listen((data) {
      stdoutFile.writeAsStringSync(
        '[${job.id}]: $data${Platform.lineTerminator}',
        mode: FileMode.append,
        flush: true,
      );
    });

    // Listen to the process's stderr stream
    job.process!.stderr.transform(utf8.decoder).listen((data) {
      stderrFile.writeAsStringSync(
        '[${job.id}]: $data${Platform.lineTerminator}',
        mode: FileMode.append,
        flush: true,
      );
    });

    // Wait for the process to exit
    await job.process!.exitCode;
  }
}

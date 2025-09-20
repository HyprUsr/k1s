import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:k1s/server/job.dart';

class JobManager {
  final Map<String, Job> _jobs = {};

  void addJob(Job job) {
    _jobs[job.id] = job;
    _processJob(job);
  }

  void removeJob(Job job) {
    _jobs.remove(job.id);
  }

  Map<String, Job> get jobs => Map.unmodifiable(_jobs);

  Future<void> _processJob(Job job) async {
    if (job is ContinuousJob) {
      while (job.killRequested == false &&
          (job.failedCount < ContinuousJob.maxFailedCount)) {
        final jobResult = JobResult();
        try {
          job.process = await Process.start(
            job.executable,
            job.arguments,
            workingDirectory: job.workingDirectory,
            environment: job.environment,
            includeParentEnvironment: false,
          );

          // Listen to the process's stdout stream
          job.process!.stdout.transform(utf8.decoder).listen((data) {
            // process.kill(ProcessSignal.sigint);
            print('${job.id} 💡 STDOUT: $data');
            jobResult.stdout += data;
          });

          // Listen to the process's stderr stream
          job.process!.stderr.transform(utf8.decoder).listen((data) {
            print('${job.id} ❗ STDERR: $data');
            jobResult.stderr += data;
          });

          // Wait for the process to exit
          jobResult.exitCode = await job.process!.exitCode;
          print('${job.id} 🔴 Process exited with code: ${jobResult.exitCode}');
        } catch (e) {
          job.failedCount += 1;
          jobResult.error = e.toString();
          print('Error running job ${job.id}: $e');
        } finally {
          job.results.add(jobResult);
        }
      }
    } else if (job is OneTimeJob) {
      try {
        final result = await Process.run(
          job.executable,
          job.arguments,
          workingDirectory: job.workingDirectory,
          environment: job.environment,
        );
        job.results.add(
          JobResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
          ),
        );
      } catch (e) {
        print('Error running job ${job.id}: $e');
        job.results.add(JobResult(error: e.toString()));
      }
    } else if (job is PeriodicJob) {
      job.timer = Timer.periodic(job.schedule, (timer) async {
        if (job.killRequested) {
          timer.cancel();
          return;
        }
        try {
          final result = await Process.run(
            job.executable,
            job.arguments,
            workingDirectory: job.workingDirectory,
            environment: job.environment,
          );
          job.results.add(
            JobResult(
              exitCode: result.exitCode,
              stdout: result.stdout,
              stderr: result.stderr,
            ),
          );
        } catch (e) {
          print('Error running job ${job.id}: $e');
          job.results.add(JobResult(error: e.toString()));
        }
      });
    }
  }
}

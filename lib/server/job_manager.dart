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
      while (job.killRequested == false) {
        final jobResult = JobResult();

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
        job.results.add(jobResult);
        print('${job.id} 🔴 Process exited with code: ${jobResult.exitCode}');
      }
    } else if (job is OneOffJob) {
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
    } else if (job is CronJob) {
      job.timer = Timer.periodic(job.schedule, (timer) async {
        if (job.killRequested) {
          timer.cancel();
          return;
        }
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
      });
    }
  }
}

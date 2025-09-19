import 'dart:convert';

import 'package:k1s/server/job.dart';
import 'package:k1s/server/job_manager.dart';

class CommandProcessor {
  final JobManager jobManager;
  final Function(String message) writer;

  CommandProcessor(this.jobManager, this.writer);

  Future<void> process(String rawCommand) async {
    final command = jsonDecode(rawCommand);

    // Process the command based on its action
    var _ = switch (command['action']) {
      'get-all-jobs' => _getAllJobs(),
      'get-job-by-id' => _getJobById(command),
      'create-job' => _createJob(command),
      'kill-job' => _killJob(command),
      'delete-job' => _deleteJob(command),
      _ => writer('Unknown command.\n'),
    };
  }

  void _getAllJobs() {
    final jobs = jobManager.jobs.values.map((job) => job.toJson()).toList();
    writer('${jsonEncode({'all-jobs': jobs})}\n');
  }

  void _getJobById(dynamic command) {
    final jobId = command['id'];
    if (jobId == null) {
      writer('${jsonEncode({'error': 'Job ID is required'})}\n');
      return;
    }
    final job = jobManager.jobs[jobId];
    if (job != null) {
      writer('${jsonEncode({'job': job.toJson()})}\n');
    } else {
      writer('${jsonEncode({'error': 'Job not found'})}\n');
    }
  }

  void _createJob(dynamic command) {
    final jobData = command['job'];
    if (jobData == null) {
      writer('${jsonEncode({'error': 'Invalid job data'})}\n');
      return;
    }
    final jobId = jobData['id'];
    if (jobId == null) {
      writer('${jsonEncode({'error': 'Job ID is required'})}\n');
      return;
    }

    Job job;
    if (jobData['type'] == 'continuous') {
      job = ContinuousJob(
        id: jobData['id'],
        executable: jobData['executable'],
        arguments: List<String>.from(jobData['arguments'] ?? []),
        workingDirectory: jobData['workingDirectory'],
        environment: Map<String, String>.from(jobData['environment'] ?? {}),
        restartOnFailure: jobData['restartOnFailure'] ?? true,
      );
    } else if (jobData['type'] == 'one-off') {
      job = OneOffJob(
        id: jobData['id'],
        executable: jobData['executable'],
        arguments: List<String>.from(jobData['arguments'] ?? []),
        workingDirectory: jobData['workingDirectory'],
        environment: Map<String, String>.from(jobData['environment'] ?? {}),
      );
    } else if (jobData['type'] == 'cron') {
      job = CronJob(
        id: jobData['id'],
        executable: jobData['executable'],
        arguments: List<String>.from(jobData['arguments'] ?? []),
        workingDirectory: jobData['workingDirectory'],
        environment: Map<String, String>.from(jobData['environment'] ?? {}),
        schedule: Duration(seconds: jobData['scheduleInSeconds']),
      );
    } else {
      writer('${jsonEncode({'error': 'Invalid job type'})}\n');
      return;
    }
    jobManager.addJob(job);
    writer('${jsonEncode({'message': 'Job created', 'id': job.id})}\n');
  }

  void _killJob(dynamic command) {
    final jobId = command['id'];
    final job = jobManager.jobs[jobId];
    if (job != null && job is ContinuousJob) {
      job.kill();
      writer('${jsonEncode({'message': 'Job killed'})}\n');
    } else {
      writer(
        '${jsonEncode({'error': 'Job not found or not a continuous job'})}\n',
      );
    }
  }

  void _deleteJob(dynamic command) {
    final jobId = command['id'];
    final job = jobManager.jobs[jobId];
    if (job != null) {
      jobManager.removeJob(job);
      writer('${jsonEncode({'message': 'Job deleted'})}\n');
    } else {
      writer('${jsonEncode({'error': 'Job not found'})}\n');
    }
  }
}

import 'dart:convert';

import 'package:k1s/commands.dart';
import 'package:k1s/job.dart';
import 'package:k1s/job_manager.dart';

class CommandProcessor {
  final JobManager jobManager;
  final Function(String message) writer;

  CommandProcessor(this.jobManager, this.writer);

  Future<void> process(String rawCommand) async {
    final command = jsonDecode(rawCommand);

    // Process the command based on its action
    var _ = switch (ClientCommand.fromName(command['command'])) {
      ClientCommand.getAllJobs => _getAllJobs(),
      ClientCommand.getJobById => _getJobById(command),
      ClientCommand.createJob => _createJob(command),
      ClientCommand.killJob => _killJob(command),
      ClientCommand.deleteJob => _deleteJob(command),
      _ => writer('Unknown command.\n'),
    };
  }

  void _getAllJobs() {
    final jobs = jobManager.jobs.values.map((job) => job.toJson()).toList();
    writer('${jsonEncode(jobs)}\n');
  }

  void _getJobById(dynamic command) {
    final jobId = command['jobId'];
    if (jobId == null) {
      writer('${jsonEncode({'error': 'Job ID is required'})}\n');
      return;
    }
    final job = jobManager.jobs[jobId];
    if (job != null) {
      writer('${jsonEncode(job.toJson())}\n');
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
    if (jobManager.jobs.containsKey(jobId)) {
      writer('${jsonEncode({'error': 'Job ID already exists'})}\n');
      return;
    }

    Job job;
    if (jobData['type'] == JobType.continuous.type) {
      job = ContinuousJob(
        id: jobData['id'],
        executable: jobData['executable'],
        arguments: List<String>.from(jobData['arguments'] ?? []),
        workingDirectory: jobData['workingDirectory'],
        environment: Map<String, String>.from(jobData['environment'] ?? {}),
        maxRetry: jobData['maxRetry'] ?? 5,
      );
    } else if (jobData['type'] == JobType.oneTime.type) {
      job = OneTimeJob(
        id: jobData['id'],
        executable: jobData['executable'],
        arguments: List<String>.from(jobData['arguments'] ?? []),
        workingDirectory: jobData['workingDirectory'],
        environment: Map<String, String>.from(jobData['environment'] ?? {}),
      );
    } else if (jobData['type'] == JobType.periodic.type) {
      job = PeriodicJob(
        id: jobData['id'],
        executable: jobData['executable'],
        arguments: List<String>.from(jobData['arguments'] ?? []),
        workingDirectory: jobData['workingDirectory'],
        environment: Map<String, String>.from(jobData['environment'] ?? {}),
        period: Duration(seconds: jobData['periodInSeconds']),
      );
    } else {
      writer('${jsonEncode({'error': 'Invalid job type'})}\n');
      return;
    }
    jobManager.addJob(job);
    writer('${jsonEncode(job)}\n');
  }

  void _killJob(dynamic command) {
    final jobId = command['jobId'];
    final job = jobManager.jobs[jobId];
    if (job != null) {
      if (job is ContinuousJob) {
        job.kill();
        writer('${jsonEncode({'message': 'Job killed'})}\n');
      } else if (job is PeriodicJob) {
        job.kill();
        writer('${jsonEncode({'message': 'Job killed'})}\n');
      } else {
        writer('${jsonEncode({'error': 'Job is not continuous or periodic'})}\n');
      }
    } else {
      writer(
        '${jsonEncode({'error': 'Job not found'})}\n',
      );
    }
  }

  void _deleteJob(dynamic command) {
    final jobId = command['jobId'];
    final job = jobManager.jobs[jobId];
    if (job != null) {
      jobManager.removeJob(job);
      writer('${jsonEncode({'message': 'Job deleted'})}\n');
    } else {
      writer('${jsonEncode({'error': 'Job not found'})}\n');
    }
  }
}

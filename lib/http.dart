import 'dart:convert';
import 'dart:io';

import 'package:k1s/job.dart';
import 'package:k1s/job_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final class Http {
  final JobManager jobManager;

  Http(this.jobManager);

  Router get router => Router()
    ..get('/', _getListAllJobsHandler)
    ..get('/job/<id>', _getJobByIdHandler)
    ..post('/job/<id>', _createJobHandler)
    ..put('/job/<id>/kill', _killJobHandler)
    ..delete('/job/<id>', _deleteJobHandler);

  Response _getListAllJobsHandler(Request req) {
    final jobs = jobManager.jobs.values.map((job) => job.toJson()).toList();
    return Response.ok(
      jsonEncode(jobs),
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
    );
  }

  Response _getJobByIdHandler(Request req, String id) {
    final job = jobManager.jobs[id];
    if (job == null) {
      return Response.notFound(
        jsonEncode({'error': 'Job not found'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }
    return Response.ok(
      jsonEncode(job.toJson()),
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
    );
  }

  Future<Response> _createJobHandler(Request req, String id) async {
    if (jobManager.jobs.containsKey(id)) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Job with id $id already exists'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }
    final payload = await req.readAsString();
    final data = jsonDecode(payload);

    if (data['type'] == 'continuous') {
      final job = ContinuousJob(
        id: id,
        executable: data['executable'],
        arguments: List<String>.from(data['arguments'] ?? []),
        workingDirectory: data['workingDirectory'] ?? Directory.current.path,
        environment: Map<String, String>.from(data['environment'] ?? {}),
        restartOnFailure: data['restartOnFailure'] ?? true,
      );
      jobManager.addJob(job);
      return Response.ok(
        jsonEncode({'message': 'Continuous job created', 'id': job.id}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    } else if (data['type'] == 'one-off') {
      final job = OneOffJob(
        id: id,
        executable: data['executable'],
        arguments: List<String>.from(data['arguments'] ?? []),
        workingDirectory: data['workingDirectory'] ?? Directory.current.path,
        environment: Map<String, String>.from(data['environment'] ?? {}),
      );
      jobManager.addJob(job);
      return Response.ok(
        jsonEncode({'message': 'One-off job created', 'id': job.id}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    } else if (data['type'] == 'cron') {
      final job = CronJob(
        id: id,
        executable: data['executable'],
        arguments: List<String>.from(data['arguments'] ?? []),
        workingDirectory: data['workingDirectory'] ?? Directory.current.path,
        environment: Map<String, String>.from(data['environment'] ?? {}),
        schedule: Duration(seconds: data['scheduleInSeconds'] ?? 60),
      );
      jobManager.addJob(job);
      return Response.ok(
        jsonEncode({'message': 'Cron job created', 'id': job.id}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    } else {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid job type'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }
  }

  Response _killJobHandler(Request req, String id) {
    final job = jobManager.jobs[id];
    if (job == null) {
      return Response.notFound(
        jsonEncode({'error': 'Job not found'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }
    if (job is ContinuousJob) {
      job.kill();
      return Response.ok(
        jsonEncode({'message': 'Kill requested for job $id'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    } else if (job is CronJob) {
      job.kill();
      return Response.ok(
        jsonEncode({'message': 'Kill requested for job $id'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    } else {
      return Response.badRequest(
        body: jsonEncode({'error': 'Job type does not support kill operation'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }
  }

  Response _deleteJobHandler(Request req, String id) {
    final job = jobManager.jobs[id];
    if (job == null) {
      return Response.notFound(
        jsonEncode({'error': 'Job not found'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }
    if (job is ContinuousJob) {
      job.kill();
    } else if (job is CronJob) {
      job.kill();
    }

    jobManager.removeJob(job);

    return Response.ok(
      jsonEncode({'message': 'Kill requested for job $id'}),
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
    );
  }
}

Middleware authenticateRequests({required String token}) => (innerHandler) {
  return (request) {
    final authHeader = request.headers[HttpHeaders.authorizationHeader];
    if (authHeader == null || authHeader != 'Bearer $token') {
      return Response.forbidden(
        jsonEncode({'error': 'Unauthorized'}),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }
    return innerHandler(request);
  };
};

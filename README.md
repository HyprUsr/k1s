# k1s

k1s is a lightweight process supervisor exposed over a REST API. It lets you register background jobs, inspect their status and history, and control long-running or scheduled processes from anywhere you can send HTTP requests.

## Features
- Manage three job categories: continuous daemons, one-off tasks, and cron-style scheduled jobs
- Inspect job metadata, recent exit codes, and captured stdout/stderr for each execution
- Kill or remove jobs remotely with authenticated API calls
- Configure the listening port and bearer token with a TOML config file
- Built on the Dart `shelf` stack for easy extension and deployment

## Prerequisites
- Dart SDK ^3.9.0 ([install instructions](https://dart.dev/get-dart))

## Getting Started
1. Install dependencies:
   ```sh
   dart pub get
   ```
2. (Optional) Create a configuration file, e.g. `config/dev.toml`:
   ```toml
   [http]
   port = 8080
   auth_token = "change-me"
   ```
3. Start the supervisor:
   ```sh
   dart run bin/server.dart -c config/dev.toml
   ```
   If no config is provided the server listens on port `1298` with the default token `abc123`.

## Authentication
Every request must include a bearer token matching the configured value:
```
Authorization: Bearer <token>
```
Requests without the header or with an incorrect token receive `403` responses.

## Job Types
| Type | Description | Key fields |
|------|-------------|------------|
| `continuous` | Starts a long-lived process and restarts it until `kill` is requested. | `restartOnFailure` (defaults to `true`), `executable`, `arguments`, `environment`, `workingDirectory` |
| `one-off` | Executes the process once and stores the result. | `executable`, `arguments`, `environment`, `workingDirectory` |
| `cron` | Runs the process periodically using a repeating timer. | `scheduleInSeconds` (defaults to `60`), `executable`, `arguments`, `environment`, `workingDirectory` |

All job types capture stdout, stderr, and exit code for each run in the `results` array.
Continuous jobs currently respawn immediately after each exit until you issue a kill; the `restartOnFailure` flag is persisted for clients and can drive stricter policies in future revisions.

## REST API
Base URL defaults to `http://localhost:1298`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | List every registered job. |
| `GET` | `/job/{id}` | Fetch a single job by identifier. |
| `POST` | `/job/{id}` | Create a job with the provided payload. Fails if the id already exists. |
| `PUT` | `/job/{id}/kill` | Request termination for long-running jobs (continuous or cron). |
| `DELETE` | `/job/{id}` | Remove a job. Continuous and cron jobs are killed prior to removal. |

### Job object schema
Example response body for a continuous job queried via `GET /job/{id}`:
```json
{
  "id": "api-server",
  "executable": "/usr/local/bin/node",
  "arguments": ["server.js"],
  "workingDirectory": "/opt/services",
  "environment": {"NODE_ENV": "production"},
  "restartOnFailure": true,
  "killRequested": false,
  "results": [
    {
      "exitCode": 0,
      "stdout": "Server ready\n",
      "stderr": ""
    }
  ]
}
```
Fields specific to a job type are only present when relevant: `restartOnFailure`/`killRequested` for continuous jobs, `schedule`/`killRequested` for cron jobs.

### Create job payloads
`POST /job/{id}` accepts JSON payloads matching the job type:

**Continuous job**
```json
{
  "type": "continuous",
  "executable": "/usr/local/bin/node",
  "arguments": ["server.js"],
  "workingDirectory": "/opt/services",
  "environment": {"NODE_ENV": "production"},
  "restartOnFailure": true
}
```

**One-off job**
```json
{
  "type": "one-off",
  "executable": "/usr/bin/python3",
  "arguments": ["scripts/report.py"],
  "workingDirectory": "/home/user/app",
  "environment": {"PYTHONPATH": "lib"}
}
```

**Cron job**
```json
{
  "type": "cron",
  "executable": "/usr/bin/backup",
  "arguments": ["--full"],
  "workingDirectory": "/var/tasks",
  "environment": {},
  "scheduleInSeconds": 300
}
```

### Kill or delete jobs
- `PUT /job/{id}/kill` returns `{ "message": "Kill requested for job <id>" }` when successful.
- `DELETE /job/{id}` removes the job (and kills it first when necessary) and returns the same message format.

Errors are reported as JSON payloads containing an `error` field and proper HTTP status codes (`400`, `403`, `404`).

## Development
- Run linting: `dart analyze`
- Run tests: `dart test`
- Format code: `dart format lib bin`

## Deployment Notes
The server listens on all IPv4 interfaces, making it suitable for containerized deployments. Set the `PORT` environment variable when running in managed hosting that injects a port at runtime.

## Contributing
1. Fork the repository and create a feature branch.
2. Run `dart format`, `dart analyze`, and `dart test` before opening a pull request.
3. Provide clear descriptions of job lifecycle changes or API updates in your PR.

## License
This project is licensed under the terms described in [`LICENSE`](LICENSE).

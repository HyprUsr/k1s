# k1s

k1s is a lightweight job orchestration server and CLI client written in Dart. The server exposes a JSON-over-TCP interface for managing local processes, while the client offers a convenient command-line wrapper around the available operations.

## Features
- Launch local executables as managed jobs with one-time, periodic, or continuous restart semantics.
- Collect stdout, stderr, and error messages into log files per job.
- Control jobs over a simple TCP socket using structured commands.
- Configure the server port with a TOML file or command-line flags.

## Prerequisites
- Dart SDK ^3.9.0 (install from https://dart.dev/get-dart)

Run `dart pub get` at the repository root before invoking the server or client so dependencies are cached.

## Configuration
The server listens on `127.0.0.1:4567` by default. You can override the port with a TOML configuration file:

```toml
# config.toml
[server]
port = 6000
```

Start the server with the config file using the `-c` flag:

```sh
dart run bin/server.dart -c config.toml
```

If the config file is omitted, the default port is used.

## Running the server
Launch the server from the project root:

```sh
dart run bin/server.dart
```

The server prints the port it is listening on and waits for client connections. Each client connection is handled sequentially; the socket closes once the command finishes processing.

## Client usage
The CLI client wraps the supported commands. Common flags:

- `-h`, `--host` (default `127.0.0.1`)
- `-p`, `--port` (default `4567`)
- `-c`, `--command` (required; one of the commands listed below)
- `-i`, `--id` (job identifier, required by several commands)

### Supported commands
- `get-all-jobs` — return a JSON array describing all tracked jobs.
- `get-job-by-id` — return details for a single job. Requires `-i <job-id>`.
- `create-job` — register and start a new job. Requires:
  - `-i <job-id>` unique identifier
  - `-t <type>` where `<type>` is `one-time`, `periodic`, or `continuous`
  - `-x <executable>` absolute or relative path to the program to run
  - optional: `-a "arg1 arg2"` to pass arguments (split on spaces), `-w <path>` working directory, `-e KEY=VALUE` environment variables (repeatable)
  - periodic jobs also require `-r <seconds>` for the interval
  - continuous jobs can set retry count with `-m <maxRetry>`; `-1` retries indefinitely
- `kill-job` — send a SIGINT to a running continuous or periodic job. Requires `-i <job-id>`.
- `delete-job` — remove a job and terminate it if still running. Requires `-i <job-id>`.

Example workflow that launches a periodic echo job every 30 seconds:

```sh
# Start the server (in another terminal)
dart run bin/server.dart

# Create the job
dart run bin/client.dart \
  -c create-job \
  -i hello-job \
  -t periodic \
  -x /bin/echo \
  -a "hello from k1s" \
  -r 30

# View all jobs
dart run bin/client.dart -c get-all-jobs

# Kill the job when done
dart run bin/client.dart -c kill-job -i hello-job
```

## Logging
Every job writes its stdout and stderr streams to files in the server's working directory:

- `stdout_<job-id>.log`
- `stderr_<job-id>.log`
- `error_<job-id>.log`

Provide custom file paths in the job payload if you extend the client; otherwise, the defaults above are used. Environment variables supplied with `-e` replace the parent environment, so include any values the executable expects.

## Development notes
- Jobs are tracked in memory; restarting the server clears all job state.
- The client/server protocol is JSON encoded on a single line per command.
- Continuous jobs restart until explicitly killed or the retry budget is exhausted.
- Periodic jobs keep the schedule until killed or they exceed the retry limit.

Feel free to extend the client or server to support authentication, persistence, or richer telemetry as needed.

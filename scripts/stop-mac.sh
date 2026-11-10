#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
repo_root="$PWD"
pid_file="${repo_root}/.data/dev.pid"

# The assistant may start this temporary macOS user job to keep services alive
# after its tool session ends. Remove the job before stopping its process tree.
if launchctl list com.oatmeal.local-dev >/dev/null 2>&1; then
  launchctl remove com.oatmeal.local-dev
fi

stop_tree() {
  local pid="$1"
  local child
  while IFS= read -r child; do
    if [[ "$child" =~ ^[0-9]+$ ]]; then stop_tree "$child"; fi
  done < <(pgrep -P "$pid" 2>/dev/null || true)
  kill -TERM "$pid" 2>/dev/null || true
}

if [[ -f "$pid_file" ]]; then
  read -r dev_pid < "$pid_file" || true
  if [[ "${dev_pid:-}" =~ ^[0-9]+$ ]] && kill -0 "$dev_pid" 2>/dev/null; then
    command_line="$(ps -p "$dev_pid" -o command= 2>/dev/null || true)"
    if [[ "$command_line" != *"scripts/dev.sh"* ]]; then
      echo "The saved process ID no longer belongs to Oatmeal AI. Check running apps before stopping Docker." >&2
      exit 1
    fi
    echo "Stopping Oatmeal AI..."
    stop_tree "$dev_pid"
    for _ in {1..30}; do
      if ! kill -0 "$dev_pid" 2>/dev/null; then break; fi
      sleep 1
    done
    if kill -0 "$dev_pid" 2>/dev/null; then
      echo "Oatmeal AI did not stop cleanly. Check the Start window." >&2
      exit 1
    fi
  fi
  rm -f "$pid_file"
  # The supervisor can exit before Next.js and Uvicorn release their sockets.
  # Give those children time to finish instead of reporting a false failure.
  for _ in {1..30}; do
    if ! lsof -tiTCP:3000 -sTCP:LISTEN >/dev/null 2>&1 \
      && ! lsof -tiTCP:8000 -sTCP:LISTEN >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  if curl --silent --fail http://127.0.0.1:3000 >/dev/null \
    || curl --silent --fail http://127.0.0.1:8000/readyz >/dev/null; then
    echo "A local app process is still running. Stop it before shutting down Docker." >&2
    exit 1
  fi
elif curl --silent --fail http://127.0.0.1:3000 >/dev/null \
  || curl --silent --fail http://127.0.0.1:8000/readyz >/dev/null; then
  echo "Oatmeal AI was started outside the launcher. Stop it in its original terminal with Ctrl+C." >&2
  exit 1
fi

whisper_binary="${repo_root}/.venv-whisper-local/bin/whisper-local"
while IFS= read -r whisper_pid; do
  if [[ ! "$whisper_pid" =~ ^[0-9]+$ ]]; then continue; fi
  command_line="$(ps -p "$whisper_pid" -o command= 2>/dev/null || true)"
  if [[ "$command_line" == *"${whisper_binary} --serve --serve-host 127.0.0.1 --serve-port 7777"* ]]; then
    kill -TERM "$whisper_pid" 2>/dev/null || true
  fi
done < <(lsof -tiTCP:7777 -sTCP:LISTEN 2>/dev/null || true)

while IFS= read -r cohere_pid; do
  if [[ ! "$cohere_pid" =~ ^[0-9]+$ ]]; then continue; fi
  command_line="$(ps -p "$cohere_pid" -o command= 2>/dev/null || true)"
  if [[ "$command_line" == *".venv-cohere-speech/bin/python -m uvicorn cohere_server:app --app-dir scripts --host 127.0.0.1 --port 7778"* ]]; then
    kill -TERM "$cohere_pid" 2>/dev/null || true
  fi
done < <(lsof -tiTCP:7778 -sTCP:LISTEN 2>/dev/null || true)

if docker info >/dev/null 2>&1; then
  docker compose down
fi
if [[ "${1:-}" == "--quit-docker" ]]; then
  if docker desktop status >/dev/null 2>&1; then
    echo "Quitting Docker Desktop..."
    docker desktop stop --timeout 60
  else
    echo "Docker Desktop is already stopped."
  fi
fi
echo "Oatmeal AI is stopped. Saved classes remain in the Docker volume."

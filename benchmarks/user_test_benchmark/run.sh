#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAMEWORK="${FRAMEWORK:-dart_orpc}"
case "$FRAMEWORK" in
  dart_orpc)
    APP_SLUG="dart_orpc_user_test_benchmark"
    FRAMEWORK_LABEL="dart_orpc"
    ;;
  dart_frog)
    APP_SLUG="dart_frog_user_test_benchmark"
    FRAMEWORK_LABEL="Dart Frog"
    ;;
  shelf)
    APP_SLUG="shelf_user_test_benchmark"
    FRAMEWORK_LABEL="Shelf"
    ;;
  *)
    printf 'Unsupported FRAMEWORK: %s (choose dart_orpc, dart_frog, or shelf)\n' "$FRAMEWORK" >&2
    exit 2
    ;;
esac
APP_DIR="$REPO_ROOT/benchmarks/apps/$APP_SLUG"
CACHE_DIR="$REPO_ROOT/benchmarks/.challenge-cache/twelve-dollar-server-challenge"
TEMPLATE_URL="https://github.com/arjaythedev/twelve-dollar-server-challenge.git"
TEMPLATE_COMMIT="026bdb68d94d0d932bb5981321ad82c70618d752"
TEMPLATE_DIR="$CACHE_DIR"

WARMUP_VUS="${WARMUP_VUS:-11000}"
WARMUP_DURATION="${WARMUP_DURATION:-5m}"
RAMP_UP="${RAMP_UP:-60s}"
HOLD_DURATION="${HOLD_DURATION:-1m}"
START_VUS="${START_VUS:-11000}"
MAX_VUS="${MAX_VUS:-0}"
VU_INCREMENT="${VU_INCREMENT:-250}"
USER_TEST_BENCHMARK_PORT="${USER_TEST_BENCHMARK_PORT:-${CHALLENGE_PORT:-3300}}"
TEST_PORT="${TEST_PORT:-3301}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
K6_DASHBOARD_PORT="${K6_WEB_DASHBOARD_PORT:-5665}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Run User Test Benchmark correctness checks and incremental k6 load for one Dart server.

Usage:
  FRAMEWORK=dart_orpc bash benchmarks/user_test_benchmark/run.sh
  FRAMEWORK=dart_frog bash benchmarks/user_test_benchmark/run.sh
  FRAMEWORK=shelf bash benchmarks/user_test_benchmark/run.sh

Framework defaults to dart_orpc. All use same seed DB, official correctness
suite, k6 profile, and 1 CPU / 2 GiB / no-swap Docker limit.
Current profile defaults: 11,000 VUs for a 5-minute warm-up, then start the
scored run at 11,000 VUs with a 60-second ramp and 1-minute hold.

Start at a specific VU count and choose each next step interactively:
  FRAMEWORK=shelf START_VUS=10000 VU_INCREMENT=1000 bash benchmarks/user_test_benchmark/run.sh

After each scored run, press Enter to add VU_INCREMENT, enter an exact next
VU count, or enter q to finish. Set MAX_VUS to cap accepted levels. For a
short local run, override WARMUP_DURATION, RAMP_UP, and HOLD_DURATION.

Set USER_TEST_BENCHMARK_PORT (or legacy CHALLENGE_PORT) or TEST_PORT if defaults are in use.
During each k6 phase, open http://127.0.0.1:5665 (or the port set by
K6_WEB_DASHBOARD_PORT). Per-phase HTML dashboards are saved under results/.../load/.
Run each framework separately with the same settings for comparable reports.
EOF
  exit 0
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 2
  fi
}

for command in dart docker git jq k6 node openssl sqlite3 curl; do
  require_command "$command"
done
if ! docker info >/dev/null 2>&1; then
  echo 'Docker is installed but its daemon is unavailable.' >&2
  exit 2
fi

RESULT_STAMP="$(date +%Y-%m-%d-%H%M%S)-$$"
SHORT_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
RESULT_DIR="$REPO_ROOT/benchmarks/results/user-test-benchmark-${FRAMEWORK}-${RESULT_STAMP}-${SHORT_COMMIT}"
mkdir -p "$RESULT_DIR"/{load,resources,logs}
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/user-test-benchmark-${FRAMEWORK}.XXXXXX")"
ACTIVE_CONTAINER=""
ACTIVE_STATS_PID=""
RUN_SEQUENCE=0
PROFILE_NUMBER=1
FINAL_LABEL=""
HIGHEST_PASS_VUS=0

if [[ ! "$START_VUS" =~ ^[1-9][0-9]*$ ]]; then
  echo 'START_VUS must be a positive integer.' >&2
  exit 2
fi
if [[ ! "$VU_INCREMENT" =~ ^[1-9][0-9]*$ ]]; then
  echo 'VU_INCREMENT must be a positive integer.' >&2
  exit 2
fi
if [[ ! "$MAX_VUS" =~ ^(0|[1-9][0-9]*)$ ]]; then
  echo 'MAX_VUS must be 0 (no cap) or a positive integer.' >&2
  exit 2
fi
if [[ "$MAX_VUS" -gt 0 && "$START_VUS" -gt "$MAX_VUS" ]]; then
  echo 'START_VUS cannot exceed MAX_VUS.' >&2
  exit 2
fi

cleanup() {
  if [[ -n "$ACTIVE_STATS_PID" ]]; then
    kill "$ACTIVE_STATS_PID" >/dev/null 2>&1 || true
    wait "$ACTIVE_STATS_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$ACTIVE_CONTAINER" ]]; then
    docker rm --force "$ACTIVE_CONTAINER" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ ! -d "$TEMPLATE_DIR/.git" ]]; then
  mkdir -p "$(dirname "$TEMPLATE_DIR")"
  git clone --depth 1 --no-checkout "$TEMPLATE_URL" "$TEMPLATE_DIR"
fi
if ! git -C "$TEMPLATE_DIR" cat-file -e "$TEMPLATE_COMMIT^{commit}" 2>/dev/null; then
  git -C "$TEMPLATE_DIR" fetch --depth 1 origin "$TEMPLATE_COMMIT"
fi
git -C "$TEMPLATE_DIR" checkout --quiet --detach "$TEMPLATE_COMMIT"

if [[ ! -s "$TEMPLATE_DIR/seed/feed.db" || ! -s "$TEMPLATE_DIR/seed/tokens.json" ]]; then
  echo 'Generating the official SQLite seed database (first run takes about a minute).'
  bash "$TEMPLATE_DIR/seed/make-seed.sh"
fi
VERIFY_DB_DIR="$TEMP_ROOT/verification"
mkdir -p "$VERIFY_DB_DIR"
cp "$TEMPLATE_DIR/seed/feed.db" "$VERIFY_DB_DIR/feed.db"

echo 'Building the host AOT server for the correctness suite...'
HOST_BUILD_START="$SECONDS"
bash "$APP_DIR/build.sh" >"$RESULT_DIR/logs/host-build.log" 2>&1 || {
  cat "$RESULT_DIR/logs/host-build.log"
  exit 1
}
HOST_BUILD_SECONDS=$((SECONDS - HOST_BUILD_START))

echo 'Running the upstream API correctness suite...'
VERIFY_START="$SECONDS"
JWT_SECRET=twelve-dollar-challenge \
SQLITE_PATH="$VERIFY_DB_DIR/feed.db" \
PORT="$TEST_PORT" \
  bash "$TEMPLATE_DIR/test/run.sh" "$APP_DIR" \
  >"$RESULT_DIR/logs/verify.log" 2>&1 || {
    cat "$RESULT_DIR/logs/verify.log"
    echo 'Correctness suite failed; benchmark stopped.' >&2
    exit 1
  }
VERIFY_SECONDS=$((SECONDS - VERIFY_START))
cat "$RESULT_DIR/logs/verify.log"

IMAGE="${FRAMEWORK}-user-test-benchmark:${RESULT_STAMP}-${SHORT_COMMIT}"
echo "Building the Linux AOT $FRAMEWORK_LABEL server image..."
DOCKER_BUILD_START="$SECONDS"
docker build --progress=plain \
  --platform "$DOCKER_PLATFORM" \
  --file "$APP_DIR/Dockerfile" \
  --tag "$IMAGE" \
  "$REPO_ROOT" \
  >"$RESULT_DIR/logs/docker-build.log" 2>&1 || {
    cat "$RESULT_DIR/logs/docker-build.log"
    exit 1
  }
DOCKER_BUILD_SECONDS=$((SECONDS - DOCKER_BUILD_START))
IMAGE_SIZE_BYTES="$(docker image inspect --format '{{.Size}}' "$IMAGE")"
HOST_BINARY_SIZE_BYTES="$(wc -c < "$APP_DIR/bin/server" | tr -d '[:space:]')"

start_server() {
  local database_path="$1"
  local name="$2"
  ACTIVE_CONTAINER="$name"
  docker run --detach \
    --platform "$DOCKER_PLATFORM" \
    --name "$name" \
    --cpus=1.0 \
    --memory=2g \
    --memory-swap=2g \
    --publish "127.0.0.1:${USER_TEST_BENCHMARK_PORT}:3000" \
    --volume "$database_path:/data/feed.db:rw" \
    --env HOST=0.0.0.0 \
    --env PORT=3000 \
    --env SQLITE_PATH=/data/feed.db \
    --env JWT_SECRET=twelve-dollar-challenge \
    "$IMAGE" >/dev/null

  for _ in $(seq 1 60); do
    if curl --silent --show-error --fail \
      "http://127.0.0.1:${USER_TEST_BENCHMARK_PORT}/health" \
      >"$TEMP_ROOT/health.json" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  docker logs "$name" >&2 || true
  echo 'No healthy /health response after 60 seconds.' >&2
  return 1
}

run_profile() {
  local label="$1"
  local vus="$2"
  local duration="$3"
  local score_run="$4"
  local database_dir="$TEMP_ROOT/$label"
  local database_path="$database_dir/feed.db"
  local summary_path="$RESULT_DIR/load/$label.json"
  local log_path="$RESULT_DIR/logs/$label.log"
  local resource_path="$RESULT_DIR/resources/$label.jsonl"
  local stop_code=0
  local passed=false
  local container_name="user-test-benchmark-${FRAMEWORK}-${RESULT_STAMP//[^a-zA-Z0-9]/}-${RUN_SEQUENCE}"
  RUN_SEQUENCE=$((RUN_SEQUENCE + 1))

  mkdir -p "$database_dir"
  cp "$TEMPLATE_DIR/seed/feed.db" "$database_path"
  start_server "$database_path" "$container_name"

  docker stats --format '{{json .}}' "$container_name" \
    >"$resource_path" 2>/dev/null &
  ACTIVE_STATS_PID=$!

  echo "LOAD $label: $vus VUs, $duration hold"
  echo "k6 dashboard: http://127.0.0.1:${K6_DASHBOARD_PORT}"
  set +e
  K6_WEB_DASHBOARD=true \
  K6_WEB_DASHBOARD_OPEN=false \
  K6_WEB_DASHBOARD_PORT="$K6_DASHBOARD_PORT" \
  K6_WEB_DASHBOARD_EXPORT="$RESULT_DIR/load/$label.html" \
  K6_SUMMARY_TREND_STATS='avg,min,med,max,p(90),p(95),p(99),p(99.9)' \
  k6 run \
    --summary-export "$summary_path" \
    --env "BASE_URL=http://127.0.0.1:${USER_TEST_BENCHMARK_PORT}" \
    --env "VUS=$vus" \
    --env "DURATION=$duration" \
    --env "RAMP_UP=$RAMP_UP" \
    --env "TOKENS=$TEMPLATE_DIR/seed/tokens.json" \
    "$TEMPLATE_DIR/bench/load.js" \
    >"$log_path" 2>&1
  stop_code=$?
  set -e

  kill "$ACTIVE_STATS_PID" >/dev/null 2>&1 || true
  wait "$ACTIVE_STATS_PID" >/dev/null 2>&1 || true
  ACTIVE_STATS_PID=""
  docker rm --force "$container_name" >/dev/null 2>&1 || true
  ACTIVE_CONTAINER=""

  if [[ ! -s "$summary_path" ]]; then
    cat "$log_path"
    echo "k6 did not create a summary for $label." >&2
    return 1
  fi
  cat "$log_path"

  if jq -e '
    .metrics.http_req_duration.values["p(95)"] < 500 and
    .metrics.http_req_duration.values["p(99)"] < 1000 and
    .metrics.http_req_failed.values.rate < 0.01
  ' "$summary_path" >/dev/null 2>&1; then
    passed=true
  fi
  if [[ "$score_run" == true && "$stop_code" -ne 0 ]]; then
    passed=false
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$label" "$vus" "$duration" "$passed" "$stop_code" \
    >>"$RESULT_DIR/attempts.tsv"
  echo "RESULT $label: $([[ "$passed" == true ]] && echo PASS || echo FAIL)"
  LAST_PASS="$passed"
}

prompt_next_vus() {
  local response
  local next_vus

  while true; do
    printf 'Next VUs [Enter +%s, exact count, or q to finish]: ' "$VU_INCREMENT"
    if ! IFS= read -r response; then
      printf '\n'
      return 1
    fi
    case "$response" in
      q|Q) return 1 ;;
      '') next_vus=$((CURRENT_VUS + VU_INCREMENT)) ;;
      *)
        if [[ "$response" =~ ^\+([1-9][0-9]*)$ ]]; then
          next_vus=$((CURRENT_VUS + BASH_REMATCH[1]))
        elif [[ "$response" =~ ^[1-9][0-9]*$ ]]; then
          next_vus="$response"
        else
          echo 'Enter a positive VU count, +increment, or q.' >&2
          continue
        fi
        ;;
    esac

    if [[ "$MAX_VUS" -gt 0 && "$next_vus" -gt "$MAX_VUS" ]]; then
      echo "Next VU count exceeds MAX_VUS=$MAX_VUS." >&2
      continue
    fi

    CURRENT_VUS="$next_vus"
    return 0
  done
}

echo 'Building per-request load profile; k6 client runs on this local machine.'
run_profile warmup "$WARMUP_VUS" "$WARMUP_DURATION" false

CURRENT_VUS="$START_VUS"
while true; do
  PROFILE_LABEL="step-${PROFILE_NUMBER}-vus-${CURRENT_VUS}"
  run_profile "$PROFILE_LABEL" "$CURRENT_VUS" "$HOLD_DURATION" true
  FINAL_LABEL="$PROFILE_LABEL"
  if [[ "$LAST_PASS" == true && "$CURRENT_VUS" -gt "$HIGHEST_PASS_VUS" ]]; then
    HIGHEST_PASS_VUS="$CURRENT_VUS"
  fi
  PROFILE_NUMBER=$((PROFILE_NUMBER + 1))
  if ! prompt_next_vus; then
    break
  fi
done

if [[ "$HIGHEST_PASS_VUS" -eq 0 ]]; then
  SCORE='No scored load level passed the thresholds.'
else
  SCORE="Highest manually tested passing level: $HIGHEST_PASS_VUS VUs. This is not an exhaustive capacity search."
fi

node "$SCRIPT_DIR/tool/report.mjs" \
  "$REPO_ROOT" "$RESULT_DIR" "$TEMPLATE_COMMIT" "$IMAGE" \
  "$DOCKER_PLATFORM" "$IMAGE_SIZE_BYTES" "$DOCKER_BUILD_SECONDS" \
  "$HOST_BUILD_SECONDS" "$HOST_BINARY_SIZE_BYTES" \
  "$VERIFY_SECONDS" "$USER_TEST_BENCHMARK_PORT" "$WARMUP_VUS" \
  "$WARMUP_DURATION" "$RAMP_UP" "$HOLD_DURATION" "$START_VUS" \
  "$MAX_VUS" "$VU_INCREMENT" "$SCORE" "$FINAL_LABEL" \
  "$HIGHEST_PASS_VUS" "$FRAMEWORK" "benchmarks/apps/$APP_SLUG"

printf '\n%s\n\n' 'Benchmark report:'
cat "$RESULT_DIR/README.md"
printf '\nRaw results: %s\n' "$RESULT_DIR"

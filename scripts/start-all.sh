#!/usr/bin/env bash
# Brings up the whole Employee Concierge system as real local processes:
# all five agents, then the orchestrator (which requires all five already
# reachable — it resolves every real Agent Card at module init). Each
# process's real stdout/stderr goes to logs/<name>.log; PIDs are tracked
# in .pids/ so stop-all.sh can shut everything down cleanly.
#
# ANTHROPIC_API_KEY, if set in the calling shell, is passed through to
# every agent and the orchestrator for real LLM answers (Phase 9). Left
# unset, every agent still boots and serves its card correctly, but real
# requests fail gracefully — the structural check this phase is about.
#
# PAYROLL_ADMIN_TOKEN and PEOPLEOPS_STAFF_TOKEN default to the same demo
# values verification/payroll and verification/peopleoperations already
# hardcode, so running those scripts against a system brought up this way
# just works. Override either to use a real secret instead.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
PID_DIR="$ROOT_DIR/.pids"
mkdir -p "$LOG_DIR" "$PID_DIR"

: "${PAYROLL_ADMIN_TOKEN:=demo-payroll-admin-secret}"
: "${PEOPLEOPS_STAFF_TOKEN:=demo-staff-secret}"
export PAYROLL_ADMIN_TOKEN PEOPLEOPS_STAFF_TOKEN

wait_for() {
    local name="$1" url="$2" attempts=0
    until curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null | grep -q '^200$'; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 30 ]; then
            echo "[FAIL] $name did not become ready at $url — see logs/$name.log"
            return 1
        fi
        sleep 1
    done
    echo "[ok] $name ready at $url"
}

start_python_agent() {
    local name="$1" dir="$2" port="$3"; shift 3
    local agent_dir="$ROOT_DIR/agents/$dir"
    if [ ! -d "$agent_dir/.venv" ]; then
        echo "building $name (uv sync)..."
        (cd "$agent_dir" && uv sync)
    fi
    echo "starting $name..."
    # A backgrounded `cd x && cmd &` runs cmd inside an extra subshell, so
    # $! there is that subshell's PID, not cmd's — stop-all.sh would then
    # kill the wrong process and leave the real one running. exec inside
    # an explicitly backgrounded subshell replaces the subshell's own
    # process image with the real command, so its PID *is* $!.
    ( cd "$agent_dir" && exec env "$@" nohup .venv/bin/python3 __main__.py \
        > "$LOG_DIR/$name.log" 2>&1 ) &
    echo $! > "$PID_DIR/$name.pid"
    wait_for "$name" "http://127.0.0.1:$port/.well-known/agent-card.json"
}

start_java_agent() {
    local name="$1" dir="$2" port="$3"; shift 3
    local agent_dir="$ROOT_DIR/agents/$dir"
    if [ ! -f "$agent_dir/target/quarkus-app/quarkus-run.jar" ]; then
        echo "building $name (mvn package)..."
        (cd "$agent_dir" && mvn -q -DskipTests -Dquarkus.analytics.disabled=true package)
    fi
    echo "starting $name..."
    ( cd "$agent_dir" && exec env "$@" nohup java -jar target/quarkus-app/quarkus-run.jar \
        > "$LOG_DIR/$name.log" 2>&1 ) &
    echo $! > "$PID_DIR/$name.pid"
    wait_for "$name" "http://127.0.0.1:$port/.well-known/agent-card.json"
}

start_python_agent parking parking 8000
start_python_agent digiops digiops 8001 ${ANTHROPIC_API_KEY:+ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"}
start_python_agent peopleoperations peopleoperations 8002 ${ANTHROPIC_API_KEY:+ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"}
start_java_agent payroll payroll 8003 PAYROLL_ADMIN_TOKEN="$PAYROLL_ADMIN_TOKEN" ${ANTHROPIC_API_KEY:+ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"}
start_java_agent travel_expense travel_expense 8004 ${ANTHROPIC_API_KEY:+ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"}

unset JAVA_HOME
if [ ! -f "$ROOT_DIR/orchestrator/target/bin/orchestrator.jar" ]; then
    echo "building orchestrator (bal build --sticky)..."
    (cd "$ROOT_DIR/orchestrator" && bal build --sticky)
fi
echo "starting orchestrator..."
( cd "$ROOT_DIR/orchestrator" && exec env ${ANTHROPIC_API_KEY:+ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"} \
    nohup bal run target/bin/orchestrator.jar \
    > "$LOG_DIR/orchestrator.log" 2>&1 ) &
wait_for orchestrator "http://127.0.0.1:9090/webhooks/received"
# `bal run <jar>` forks its own JVM rather than exec'ing into it, so $!
# above is bal's launcher PID, not the real one listening on 9090 — find
# the actual listener now that wait_for has confirmed it's up.
lsof -i :9090 -sTCP:LISTEN -t | head -1 > "$PID_DIR/orchestrator.pid"

echo
echo "=== all six processes up ==="
echo "Parking:            http://127.0.0.1:8000"
echo "DigiOps:             http://127.0.0.1:8001"
echo "PeopleOperations:    http://127.0.0.1:8002"
echo "Payroll:             http://127.0.0.1:8003 (grpc: 9003)"
echo "Travel & Expense:    http://127.0.0.1:8004"
echo "Orchestrator:        http://127.0.0.1:9090 (webhook receiver)"
echo
echo "Run scripts/run-structural-checks.sh next, or scripts/stop-all.sh when done."

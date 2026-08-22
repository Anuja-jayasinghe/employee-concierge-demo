# Parking Manager Agent

A real A2A listener agent for WSO2 office parking availability and
reservations. Generic name for now — see [`../../NAMING.md`](../../NAMING.md)
for the pending WSO2-internal rename.

Deliberately built with **no LLM framework at all** — per the architecture,
this is the one agent proving A2A works correctly without an LLM in the
loop. Logic is plain deterministic Python.

## Stack

Python 3.12 · `uv` · [`a2a-sdk`](https://pypi.org/project/a2a-sdk/) 1.1.0 ·
REST (HTTP+JSON) binding · port 8000.

## Run it

```sh
cd agents/parking
uv sync
uv run __main__.py
```

Agent card: `http://127.0.0.1:8000/.well-known/agent-card.json`

## What it does

- **`sendMessage`** — "is spot A01 free?" answered directly as a plain
  `Message`, no task created.
- **Task lifecycle** — "reserve spot A01" creates a task that spends a few
  seconds in `WORKING` ("checking with facilities") before resolving to
  `COMPLETED` (spot reserved) or `REJECTED` (already taken). That window
  exists specifically so `cancelTask` has something real to interrupt.
- **`cancelTask`** — cancels a pending reservation mid-flight; correctly
  fails with `TaskNotCancelableError` against an already-terminal task.
- **Push-notification config CRUD** — `createTaskPushNotificationConfig`
  and `deleteTaskPushNotificationConfig` on a reservation's task. Actual
  webhook *delivery* is orchestrator-side work (Phase 6 of the
  [implementation plan](../../docs/implementation-plan.md)); this proves
  the config CRUD surface.

## Mock data

A small fixed set of spots at WSO2's Colombo HQ (`data.py`) — real, public,
harmless fact used for flavor; the spots and reservations themselves are
entirely fictional.

## Verification

[`../../verification/parking`](../../verification/parking) is a real
`ballerina/a2a` client script that exercises every operation above against
the running agent — no mocks. Run the agent first, then:

```sh
cd verification/parking
bal run --sticky
```

Requires `ballerina/a2a` available in your local Ballerina package
repository (`bal pack && bal push --repository=local` from the
`a2a-ballerina` checkout).

# Orchestrator

WSO2 Employee Concierge orchestrator: a real `ballerina/ai` `Agent` on a
real Anthropic model, routing employee requests to five real downstream
agents via five real `ballerina/a2a` tool functions, plus the
push-notification webhook receiver (Phase 6) all five agents can point
at — one process hosting both the outbound agent-calling logic and this
inbound receiver.

Real Anthropic backing via `ballerinax/ai.anthropic` from the start — no
stub model. See the
["Everything real, nothing simulated"](../CLAUDE.md) rule for why.

## Stack

Ballerina · `ballerina/http` (webhook receiver, port **9090**) ·
`ballerina/ai` + `ballerinax/ai.anthropic` (routing agent) ·
`ballerina/a2a` (five real client connections to Parking, DigiOps,
PeopleOperations, Payroll, and Travel & Expense) · `ai:Listener` (chat
service, port **8090** — see "Chatting with it" below).

**Must always be built/run with `--sticky`** — see the real
grpc/http-native ABI-coupling issue noted in `.gitignore` and in the
Phase 7 scaffolding commit; `Dependencies.toml` is committed for this
package specifically because of it.

## Run it

All five downstream agents must be reachable first — module init resolves
all five real Agent Cards at startup, so the orchestrator fails to boot
if any one of them isn't up (see `agent_tools.bal`), **no matter what
starts the orchestrator** — a bare `bal run`, `scripts/start-all.sh`, or
BI's own Run/Debug button all hit the same requirement:

```sh
../scripts/start-agents.sh      # brings up all five, then stops (no orchestrator)
export ANTHROPIC_API_KEY=...    # required for real routing / real answers
bal run --sticky
```

Running through WSO2 Integrator: BI instead of `bal run --sticky`? Same
prerequisite — run `scripts/start-agents.sh` from a terminal first, *then*
use BI's Run/Debug or chat panel on `orchestrator/`. Skipping that step is
exactly what produces BI's `error: Something wrong with the connection` —
it isn't a BI-compatibility issue, it's this same reachability requirement
surfacing through a different launcher.

Without `ANTHROPIC_API_KEY`, the orchestrator still boots and holds all
five real downstream connections, but any real routing request fails
gracefully with a typed error — verified, see below.

## What it does

- **`concierge` (`ai:Agent`)** — the real routing layer. Given a natural-language
  employee request, the real Anthropic model picks which of the five real
  tools to call and relays the real target agent's answer back. Full
  routing verification (does it pick the right tool) is Phase 9's job,
  once a real key is supplied.
- **`POST /concierge/chat` (`chat_service.bal`)** — `concierge` exposed on
  an `ai:Listener` (port 8090) as a real `ai:ChatService`, so it can be
  chatted with directly (`{"sessionId": "...", "message": "..."}` in,
  `{"message": "..."}` out) and, per below, driven from WSO2 Integrator:
  BI's chat panel.
- **Twenty tool functions (`agent_tools.bal`)**, four per agent (Parking,
  DigiOps, PeopleOperations, Payroll, Travel & Expense): `askXAgent` for a
  new request, `cancelXTask`/`getXTaskStatus`/`listXTasks` for a real
  cancelTask/getTask/listTasks call against an existing one. Each agent
  holds its own reusable `ballerina/a2a` `Client`, resolved against the
  real target's Agent Card once at module init — real client, real card,
  real target agent, no bypass. `askXAgent` replies now include the real
  task id (e.g. "(task id: abc-123)") when the result is a `Task`, so
  `concierge`'s own conversation memory lets it call the matching
  cancel/status tool on a later turn without the employee repeating the
  id. Push-notification config CRUD is deliberately not exposed as a chat
  tool — it doesn't map to a synchronous request/reply turn, and support
  for it is asymmetric across the five agents anyway. All twenty are
  directly callable and independently testable without the AI layer at
  all.

- **`POST /webhooks/push`** — accepts a real push-notification delivery
  from any agent's `PushNotificationSender`. Handles both wire shapes
  seen in this demo: a2a-java's flat `{"id": ..., "status": {...}}`, and
  a2a-python's `StreamResponse`-enveloped `{"task": {...}}` /
  `{"statusUpdate": {...}}`. Logs each real delivery (task ID,
  `status.state`, `X-A2A-Notification-Token`) into an in-memory list.
- **`GET /webhooks/received`** — returns everything received so far, as
  JSON. Real introspection, not a mock — used by
  `verification/webhook_receiver` to assert delivery actually happened.

## Chatting with it

Once running (locally or via BI's Run/Debug), talk to `concierge` directly
over HTTP:

```sh
curl -s http://127.0.0.1:8090/concierge/chat \
  -H 'Content-Type: application/json' \
  -d '{"sessionId": "demo-1", "message": "is there parking available today?"}'
```

**In WSO2 Integrator: BI**: run `../scripts/start-agents.sh` first (see
"Run it" above — BI's Run button doesn't start the five downstream
agents for you), then open `orchestrator/` in BI, select the Design
canvas's `AI Agent Service` entry point (`chatListener` → `/concierge`),
and use its chat panel — BI drives the same `POST /concierge/chat`
resource under the hood. See
[`../docs/research/wso2-integrator-bi-compatibility.md`](../docs/research/wso2-integrator-bi-compatibility.md)
for why this file (`chat_service.bal`) had to be added for BI to render
`concierge` as a chat agent at all, rather than showing only the webhook
receiver's plain `http:Listener`.

## A real finding from building this

Push-notification delivery was verified against all three agents that
declare the capability (Parking, Payroll, Travel & Expense), but Payroll
and Travel & Expense's delivery is **genuinely racy** in a2a-java
1.1.0.Final, not flaky test infrastructure: the SDK registers an inline
`taskPushNotificationConfig` (sent in the same `sendMessage` call) only
after consuming the first event back from the executor
(`DefaultRequestHandler.onMessageSend`), so a synchronous agent whose
entire submit → startWork → LLM-call-fails sequence happens within the
same instant can race past that registration before it lands. The
terminal `FAILED` transition specifically never delivers at all: an
uncaught executor exception is converted to `FAILED` by a framework
handler that doesn't route through the same
`AgentEmitter -> MainEventBusProcessor -> PushNotificationSender`
pipeline an explicit status update does. Parking (Python, `a2a-sdk`) has
no equivalent race and delivers reliably across its whole lifecycle,
including the terminal state.

`verification/webhook_receiver` documents this in full and handles it
honestly — Parking is asserted deterministically in one attempt; Payroll
and Travel & Expense retry a fresh request (a legitimate technique for an
asynchronous, eventually-racy real system) until one delivery lands,
rather than asserting something the SDK doesn't actually guarantee.

## Verification: push-notification delivery (Phase 6)

[`../verification/webhook_receiver`](../verification/webhook_receiver) is
a real `ballerina/a2a` script exercising all three agents against a real
running receiver — no key needed for any of it, since every check here is
about the push-notification mechanism itself, not LLM content:

```sh
# start the receiver, then Parking, Payroll, and Travel & Expense (see
# each agent's own README), then:
cd verification/webhook_receiver
bal run --sticky
```

## Verification: tools and the routing agent (Phase 7)

No separate `verification/orchestrator` package — the tools and the agent
are internal logic, not a new server-side protocol surface the way every
other agent's `AgentExecutor` was, so `bal test` (Ballerina's own,
real testing framework — not a mock) is the right tool for this, the same
way it would be for any other internal Ballerina package logic:

```sh
# start all five downstream agents first (see each one's own README), then:
cd orchestrator
bal test --sticky
```

`tests/agent_tools_test.bal` calls each of the five tool functions
directly — all five are real LLM-backed agents, so each is asserted for
real content with a key present, and graceful failure without one.
`tests/concierge_agent_test.bal` does the same for the real `ai:Agent`
itself. Every check here runs against real, live agent processes over the
real `ballerina/a2a` wire — nothing here is mocked, only the *invocation
mechanism* (a test runner instead of a standalone script) differs from
the other verification/ packages.

# Employee Concierge — Implementation Plan

Status: **draft, awaiting review**. See [`architecture.md`](architecture.md) for the
approved system design this plan implements.

## Decisions locked in for this plan

| Decision | Answer |
|---|---|
| Repo | Monorepo, public — `github.com/Anuja-jayasinghe/employee-concierge-demo` |
| LLM provider | Anthropic Claude, all agents and the orchestrator |
| MCP | Out of scope. Every agent's data is mocked and reached through plain tool functions |
| Deployment | Local processes first (manual rough-check pass), Docker Compose once that's verified and reviewed |
| Naming | Current names stay for now except HR → **PeopleOperations**, IT Helpdesk → **DigiOps**. Payroll / Parking / Travel & Expense get real WSO2 names later — tracked in [`NAMING.md`](../NAMING.md) so nothing gets lost |
| Data realism | Mock data may reference real, harmless, public WSO2 facts (office locations, general org shape) for flavor. Never a fabricated "real" record — no real figures, real policy text, or anything that could be mistaken for an actual internal document |
| Timeline | No fixed date — move as fast as correctness allows |
| API key | Every agent is built with **real** Anthropic backing from the start — no stub/fake model, no simulated agent. See below. |
| Git workflow | See `CLAUDE.md`: never commit to `main`, one branch per feature (sub-branched for large features), small commits per piece of a feature, push/PR/merge only on explicit approval, no squash merges |

## Everything real, nothing simulated

Every agent — PeopleOperations, DigiOps, Payroll, Parking, Travel & Expense — is a
real agent with a real LLM (Anthropic) as its actual reasoning backend. The
connections between agents are real A2A protocol calls over each agent's declared
transport binding, made by the orchestrator's real `ballerina/a2a` client against
real, independently running remote agents, each built on its own real A2A SDK
(`a2a-python`, `a2a-java`). Nothing is mocked, stubbed, or bypassed at the agent or
protocol layer.

**Practical consequence**: any LLM-dependent behavior (an agent's actual reasoning,
the orchestrator's routing decisions) can't be exercised until the real Anthropic key
is supplied — that's a genuine gating condition on *running* those specific tests, not
something to be worked around by building a fake implementation. Work that doesn't
need the model to produce output — agent card resolution, task state machines,
transport-binding correctness, push-notification config CRUD, Parking's logic (which
never needed an LLM in the first place per the architecture) — proceeds and gets fully
tested regardless of key availability. Everything else gets built for real and waits
for the key to actually run, rather than being faked in the meantime.

## Phases

### Phase 0 — Scaffolding (mostly done)
- [x] Repo created, pushed, added to the workspace
- [x] `docs/architecture.md` — the approved design
- [ ] `NAMING.md` at repo root — tracks confirmed vs. placeholder agent names
- [ ] Monorepo layout: `orchestrator/`, `agents/parking/`, `agents/digiops/`,
      `agents/peopleoperations/`, `agents/payroll/`, `agents/travel-expense/`,
      `webhook-receiver/`, `scripts/` (smoke test, process management)
- [ ] `.claude/skills/` scaffolding for the skills above (created as each is first needed)

**Done when:** repo structure exists, empty agent directories with placeholder
`README.md`s, nothing implemented yet.

### Phase 1 — Parking Agent (build first: simplest, zero LLM dependency)
Python · no framework · a2a-python SDK · REST binding

- [x] `AgentExecutor` serving a static agent card (skills: spot lookup, reservation)
- [x] Mock spot data (a small fixed set, WSO2-office-flavored naming)
- [x] `sendMessage` — "is spot X free" answered directly
- [x] Task lifecycle: reservation as a task, `cancelTask` support
- [x] Push notification config CRUD (create + delete; this is the agent's proof of
      `createTaskPushNotificationConfig`/`deleteTaskPushNotificationConfig`)

**Test — fully real, no stubs needed:**
- [x] Agent card resolves correctly at `/.well-known/agent-card.json`
- [x] `ballerina/a2a` `RestClient` (via `Client`) against it: `sendMessage`, `cancelTask`,
      push-notification CRUD all succeed — see `verification/parking`, 6/6 passing
- [x] Negative case: reserving an already-taken spot fails gracefully with a typed error
      (also covered: canceling an already-terminal task correctly fails)

**Done when:** every operation in Parking's "Proves" list in `architecture.md` passes
against a real `ballerina/a2a` client call, committed with its own README. **Complete** —
see `agents/parking/` and `verification/parking/`.

### Phase 2 — DigiOps Agent (IT Helpdesk)
Python · Google ADK · a2a-python SDK · JSON-RPC binding · real Anthropic backing

- [x] `AgentExecutor` wrapping a real ADK agent, configured against the real
      Anthropic model from the start — no interim fake implementation
- [x] `sendMessage` — FAQ answers (VPN, password reset)
- [x] Task lifecycle: hardware/ticket request (`getTask`/`cancelTask`/`listTasks`)
- [x] `sendStreamingMessage` + `subscribeToTask` — live incident investigation,
      genuinely droppable and resumable (verified with a real deliberate
      mid-stream disconnect + resubscribe, not just one uninterrupted stream)

**Test:**
- [x] Buildable and code-complete; agent-card resolution and streaming mechanics
      (real events, real disconnect+resubscribe) verified with no key needed —
      see `verification/digiops`, structural checks passing
- [x] Confirmed the whole ADK -> A2A -> `ballerina/a2a` pipeline fails gracefully
      (typed error, no crash/hang) without a real key
- [ ] **Full functional content — actual FAQ answers, ticket handling, real
      diagnosis text — happens in Phase 9**, since that needs the real model

### Phase 3 — PeopleOperations Agent (HR)
Python · LangGraph · a2a-python SDK · JSON-RPC binding · real Anthropic backing

- [x] `AgentExecutor` wrapping a real LangGraph graph on `ChatAnthropic` from the start
- [x] `sendMessage` — policy Q&A
- [x] `sendStreamingMessage` + `subscribeToTask` — onboarding checklist, multi-step
      (LangGraph's own tool-calling *is* the progress narration), `cancelTask` support
- [x] `getExtendedAgentCard` — a staff-only "case escalation" skill present only on
      the authenticated extended card, gated by a real bearer-token check

**Test:**
- [x] Agent-card resolution and the public-vs-extended-card diff verified now (no
      LLM call involved) — see `verification/peopleoperations`, 2 vs 3 skills confirmed
      against a real request both ways
- [x] Confirmed the LangGraph -> A2A -> `ballerina/a2a` pipeline fails gracefully
      without a real key
- [ ] **Full functional content — actual policy answers, onboarding — happens in
      Phase 9**, since every step here needs the real model (unlike DigiOps's
      incident flow, there's no pre-LLM staged narration to observe meanwhile)

### Phase 4 — Payroll Agent
Java · a2a-java SDK · Quarkus · gRPC binding · real Anthropic backing (via `langchain4j-anthropic`)

- [x] `AgentExecutor` (a2a-java), real Anthropic model (langchain4j) from the start,
      same pattern already proven on `dice_agent` earlier in this project
- [x] Task lifecycle: payslip-correction request (`getTask`/`cancelTask`/`listTasks`)
- [x] Full push-notification CRUD — all four operations verified against a real task
      (this is the one agent proving `listTaskPushNotificationConfigs`, the
      least-covered op elsewhere) — `InMemoryPushNotificationConfigStore` turned out
      to be auto-wired by CDI, no extra code needed
- [x] `getExtendedAgentCard` — admin-only "adjust another employee's payroll" skill,
      gated by a real bearer-token check via a Quarkus `@GlobalInterceptor` scoped to
      just that RPC. Rejects outright rather than downgrading like PeopleOperations —
      the a2a-java gRPC reference module (1.1.0.Final) has no per-caller card-modifier
      hook, confirmed by reading the SDK source

**Test:**
- [x] Agent-card resolution (gRPC-only `supportedInterfaces`), push-notification config
      CRUD (create/get/list/delete against a real task ID recovered from a graceful
      LLM-call failure), and extended-card admin gating (both unauthenticated-rejected
      and authenticated-3-skills) all verified now, no key needed — see
      `verification/payroll`
- [x] Confirmed the langchain4j -> A2A -> gRPC -> `ballerina/a2a` pipeline fails
      gracefully without a real key, and that `getTask`/`cancelTask` genuinely
      round-trip over gRPC
- [ ] **Task-lifecycle functional testing (actual payslip-correction content from a
      real answer) happens in Phase 9**, via `ballerina/a2a`'s `GrpcClient`

**Real integration issues found and fixed for real (not worked around), documented
in `agents/payroll/README.md` and inline in `application.properties`:**
- gRPC and plain HTTP need separate ports — combining them (as the reference sample
  this was modeled on does) broke the well-known agent-card HTTP GET
- ballerina/http's client defaults to HTTP/2 cleartext prior-knowledge negotiation,
  which doesn't interop with Vert.x's h2c handling; fixed by pinning this agent's
  HTTP listener to HTTP/1.1 rather than requiring every `ballerina/a2a` caller to
  know to override `httpVersion`

### Phase 5 — Travel & Expense Agent
Java · a2a-java SDK · REST binding · real Anthropic backing

- [x] Task lifecycle: expense claim (`getTask`/`cancelTask`/`listTasks`), real
      langchain4j-anthropic agent + two real tools (fileExpenseClaim, getClaimStatus)
- [x] Push notification config: create + get (deliberately narrower than Payroll,
      which already proved full CRUD)

**Test:**
- [x] Agent-card resolution (REST-only `supportedInterfaces`), task-lifecycle
      round-tripping (`getTask`/`cancelTask`), and push-notification create+get all
      verified now, no key needed — see `verification/travel_expense`
- [x] Confirmed the langchain4j -> A2A -> REST -> `ballerina/a2a` pipeline fails
      gracefully without a real key
- [ ] **Task-lifecycle functional testing (actual expense-claim content from a real
      answer) happens in Phase 9**, via `ballerina/a2a`'s `RestClient`

**Two of Payroll's real integration fixes applied pre-emptively here** (documented
in `agents/travel_expense/README.md`, reproduced once each to confirm they weren't
gRPC-specific before pinning): HTTP/2 pinned off on the HTTP listener, and
`protobuf-java`/`protobuf-java-util` pinned to 4.34.2 — the a2a-java 1.1.0.Final spec
types turned out to be protobuf messages regardless of transport, not just for gRPC.

### Phase 6 — Push-notification webhook receiver
- [x] Minimal HTTP endpoint the orchestrator hosts (`orchestrator/webhook_receiver.bal`,
      port 9090) — the first piece of the `orchestrator/` package, which Phase 7 builds
      the AI/tool-calling logic into
- [x] Payroll, Parking, and Travel & Expense all genuinely registered and triggered
      against it
- [x] Test: trigger a real state change on each of the three agents, confirm the
      webhook POST actually arrives — this is what turns "config CRUD works" into
      "notifications actually work," per the gap flagged when this architecture was
      first reviewed. **Everything here was testable with no Anthropic key** — see
      `verification/webhook_receiver`

**Real finding, not worked around:** a2a-java (1.1.0.Final) registers an inline
`taskPushNotificationConfig` only after consuming the executor's first event, so a
synchronous agent (Payroll, Travel & Expense) whose whole submit -> startWork ->
LLM-call-fails sequence happens in one instant can race past that registration —
confirmed by reproduction, delivery is genuinely non-deterministic for those two, and
the terminal FAILED transition never delivers at all (an uncaught executor exception's
conversion to FAILED bypasses the push pipeline entirely). Parking (Python) has no
equivalent race and delivers reliably end to end. Documented in full in
`orchestrator/README.md`; the verification script handles this honestly — Parking
asserted deterministically, Payroll/Travel & Expense retried until one real delivery
lands, rather than asserting something the SDK doesn't actually guarantee.

### Phase 7 — Orchestrator
Ballerina · `ballerina/ai` · `ballerina/a2a` client · real Anthropic backing

- [x] Five tool functions, each resolving its target agent's card once and holding a
      reusable `ballerina/a2a` `Client`
- [x] Each tool function is code-complete and calls its real target agent via real
      `ballerina/a2a` — no bypass. Against Parking specifically (the one agent that
      doesn't need the key to run), this is fully testable now — real `bal test`
      confirms a real content reply
- [x] Wire the five tools into a real `ballerina/ai` `Agent` (routing decision layer)
      on the real Anthropic model (`ballerinax/ai.anthropic`, claude-sonnet-4-5) —
      code-complete now, but actually invoking it means invoking the real model, so
      full routing verification happens in Phase 9. Confirmed now: the whole
      `ballerina/ai -> ballerinax/ai.anthropic -> Anthropic API` pipeline fails
      gracefully without a real key
- [x] Push-notification webhook receiver wired in (Phase 6) — same `orchestrator/` package

**Test:** no separate `verification/orchestrator` package — the tools and the agent
are internal logic, not a new server-side protocol surface, so `bal test`
(`orchestrator/tests/`) is the real (not mocked) tool for this. All 6 checks pass
against all five real running downstream agents — see `orchestrator/README.md`.

**Real, upstream-known issue found and fixed for real:** combining `ballerina/ai`
with `ballerina/a2a`'s gRPC binding in one package hits a grpc/http-native
ABI-coupling bug (ballerina-platform/ballerina-library#2496) — a fresh dependency
resolve picks an `http` version newer than what the bundled `grpc` module tolerates,
crashing at boot. Fixed the same way `ballerina/a2a`'s own `Ballerina.toml` already
documents: pin `http` as a floor and commit the resolved `Dependencies.toml` as the
real source of truth, always building/running this package with `--sticky`.

### Phase 8 — Local process bring-up (structural check, ahead of the key)
- [ ] All five agents + orchestrator started as local processes on fixed ports
      (matching this project's existing reference-agent pattern)
- [ ] Confirm every agent serves its agent card correctly and the orchestrator can
      resolve all five
- [ ] Run whatever slice of the smoke test doesn't require the key: Parking's full
      operation set, plus agent-card and push-notification-config checks on the
      other four
- [ ] This is a structural readiness check, not the real functional pass — that's Phase 9

**Done when:** the whole system is running, every agent is reachable and serving a
correct card, and everything that *can* be verified without the key has been.

### Phase 9 — Full functional pass with the real key
Only once the Anthropic key is supplied. This is where DigiOps, PeopleOperations,
Payroll, Travel & Expense, and the orchestrator's routing all get their first real
functional test — plan for this being the biggest single testing phase, not a quick
confirmation pass.

- [ ] `a2a-smoke-test` skill run: every one of the 11 operations, across all three
      transport bindings, exercised end-to-end against the real running system
- [ ] Run a **fixed, pre-scripted** set of end-to-end employee scenarios, written down
      in `DEMO_SCRIPT.md` *before* running them, so there's no ad-hoc repeated
      querying against the real API — script first, then execute once
- [ ] Confirm orchestrator routing quality across all five agents with the real model
- [ ] Record results; only re-run a scenario if it genuinely failed and needs a fix
      verified, not for exploratory iteration

### Phase 10 — Negative / chaos testing
- [ ] Reuse this session's fault-injection harness pattern against the now-real
      running agents: malformed responses, concurrent load, resource-leak sanity
- [ ] Write up results as a short report — this doubles as a contribution toward
      `a2a-ballerina`'s own conformance checklist (Negative Test Report step)

### Phase 11 — Documentation finalization
- [ ] Per-agent `README.md` (role, skills, how to run, port, transport binding)
- [ ] `DEMO_SCRIPT.md` — the actual presentation walkthrough
- [ ] `NAMING.md` updated with any confirmed WSO2 names, renames applied throughout
      code + docs in one pass (not piecemeal)
- [ ] `architecture.md` re-checked against what was actually built, corrected if
      anything drifted during implementation

### Phase 12 — Containerization (Docker Compose)
Only after Phase 8–11 are done and reviewed, per the agreed sequencing.

- [ ] Dockerfile per agent + orchestrator
- [ ] `docker-compose.yml` bringing the whole system up
- [ ] Re-run the Phase 9 smoke test against the containerized version, confirm parity
      with the local-process version

### Phase 13 — Final polish
- [ ] Full walkthrough rehearsal against `DEMO_SCRIPT.md`
- [ ] Anything cosmetic (WSO2 naming still pending, README polish) closed out

## Testing philosophy summary

Every agent is real from the start; what's genuinely gated on the key is *running*
anything that invokes an agent's actual reasoning — not the agent's existence or
correctness as code.

| Layer | What it proves | Needs real LLM key to run? |
|---|---|---|
| Agent card resolution (all 5 agents) | Each agent is discoverable and its card is well-formed | No |
| Push-notification config CRUD (Payroll, Parking, Travel & Expense) | Pure data storage, no reasoning involved | No |
| Parking's full operation set | The one agent with no LLM in its design at all | No |
| Orchestrator tool functions, called directly | Each tool correctly reaches its agent via `ballerina/a2a` (against Parking; the other four need the key to respond meaningfully) | Partially — Parking only |
| Task lifecycle on DigiOps / PeopleOperations / Payroll / Travel & Expense | The agent actually handles a message and manages task state | **Yes** |
| Orchestrator routing quality | The LLM actually picks the right specialist | **Yes** |
| Negative/chaos testing | Graceful failure under malformed input and load | No (targets protocol-level faults, not agent reasoning) |

Phase 9 is deliberately the largest testing phase in this plan — that's the honest
shape of "everything is real": most of the system's actual behavior can only be
verified once the key exists, and the plan is scripted (`DEMO_SCRIPT.md` written
before Phase 9 runs) so that pass is deliberate and bounded, not exploratory.

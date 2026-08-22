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
| API key | **Deferred.** Every agent and the orchestrator is built and tested against a stubbed/deterministic model first. The real Anthropic key gets plugged in only for a small number of deliberate, scripted passes once supplied — not burned on iterative dev |

## The API-key-deferred build strategy

This is the one decision that reshapes the whole plan, so it's worth stating explicitly
before the phases below.

Every agent that reasons with an LLM (PeopleOperations, DigiOps, and — optionally, for
response narration — Payroll and Travel & Expense) gets built with a **swappable model
seam**: a fake/deterministic model implementation stands in during development, and
the only thing that changes when the real key arrives is which model gets constructed.
Concretely:

- **LangGraph (PeopleOperations)**: a `FakeListLLM`/deterministic chat model during
  build; swap to `ChatAnthropic` for the real pass.
- **Google ADK (DigiOps)**: ADK's own test/mock model backend during build; swap to
  the real Anthropic-backed model for the real pass (mirrors how the ADK reference
  agent in this project was already reconfigured to Anthropic).
- **LangChain4j (Payroll, Travel & Expense, if narration is used)**: a canned-response
  model implementation during build; swap to `langchain4j-anthropic` for the real pass
  (same pattern already proven on `dice_agent`).
- **Parking**: no LLM at all, ever — pure deterministic logic per the architecture doc.
  Zero API dependency, fully testable from day one.
- **Orchestrator (`ballerina/ai`)**: the one place a real LLM is *central* to the demo's
  actual value — routing decisions. Its five tools (each a thin `ballerina/a2a` client
  call) get tested **directly**, bypassing the LLM entirely, so the plumbing is fully
  verified before the key exists. Only the final "does the LLM route correctly" check
  needs the real key.

This means every phase below except the very last real-key pass produces genuine,
verifiable progress with zero API spend.

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

- [ ] `AgentExecutor` serving a static agent card (skills: spot lookup, reservation)
- [ ] Mock spot data (a small fixed set, WSO2-office-flavored naming)
- [ ] `sendMessage` — "is spot X free" answered directly
- [ ] Task lifecycle: reservation as a task, `cancelTask` support
- [ ] Push notification config CRUD (create + delete; this is the agent's proof of
      `createTaskPushNotificationConfig`/`deleteTaskPushNotificationConfig`)

**Test — fully real, no stubs needed:**
- [ ] Agent card resolves correctly at `/.well-known/agent-card.json`
- [ ] `ballerina/a2a` `RestClient` (or `Client`) against it: `sendMessage`, `cancelTask`,
      push-notification CRUD all succeed
- [ ] Negative case: reserving an already-taken spot fails gracefully with a typed error

**Done when:** every operation in Parking's "Proves" list in `architecture.md` passes
against a real `ballerina/a2a` client call, committed with its own README.

### Phase 2 — DigiOps Agent (IT Helpdesk)
Python · Google ADK · a2a-python SDK · JSON-RPC binding

- [ ] `AgentExecutor` wrapping an ADK agent, stub model during build
- [ ] `sendMessage` — FAQ answers (VPN, password reset)
- [ ] Task lifecycle: hardware/ticket request (`getTask`/`cancelTask`/`listTasks`)
- [ ] `sendStreamingMessage` + `subscribeToTask` — live incident investigation,
      genuinely droppable and resumable (test by killing the client connection
      mid-stream and resubscribing, not just letting one stream run uninterrupted)

**Test:**
- [ ] Structural: task lifecycle and streaming work end-to-end with the stub model
- [ ] `ballerina/a2a` client coverage of every op in DigiOps's "Proves" list
- [ ] Deferred: real-model FAQ answer quality (Phase 9)

### Phase 3 — PeopleOperations Agent (HR)
Python · LangGraph · a2a-python SDK · JSON-RPC binding

- [ ] `AgentExecutor` wrapping a LangGraph graph, stub model during build
- [ ] `sendMessage` — policy Q&A
- [ ] `sendStreamingMessage` + `subscribeToTask` — onboarding checklist, multi-step,
      streamed live, genuinely reconnectable (same rigor as DigiOps's stream test)
- [ ] `getExtendedAgentCard` — a staff-only "case escalation" skill present only on
      the authenticated extended card, absent from the public one

**Test:**
- [ ] Structural: onboarding stream + reconnect, extended-card diff (public vs.
      authenticated response literally differ in `skills[]`)
- [ ] `ballerina/a2a` client coverage of every op in PeopleOperations's "Proves" list

### Phase 4 — Payroll Agent
Java · a2a-java SDK · Quarkus · gRPC binding

- [ ] `AgentExecutor` (or a2a-java's equivalent), stub/canned model if narration is used
- [ ] Task lifecycle: payslip-correction request (`getTask`/`cancelTask`/`listTasks`)
- [ ] Full push-notification CRUD — all four operations (this is the one agent proving
      `listTaskPushNotificationConfigs`, the least-covered op elsewhere)
- [ ] `getExtendedAgentCard` — admin-only "adjust another employee's payroll" skill

**Test:**
- [ ] `ballerina/a2a` `GrpcClient` coverage of every op in Payroll's "Proves" list
- [ ] Push-notification config round-trip: create → get → list → delete, each verified
      independently

### Phase 5 — Travel & Expense Agent
Java · a2a-java SDK · REST binding

- [ ] Task lifecycle: expense claim (`getTask`/`cancelTask`/`listTasks`)
- [ ] Push notification config: create + get

**Test:**
- [ ] `ballerina/a2a` `RestClient` coverage of every op in Travel & Expense's "Proves" list

### Phase 6 — Push-notification webhook receiver
- [ ] Minimal HTTP endpoint the orchestrator hosts
- [ ] Payroll, Parking, and Travel & Expense's registered configs point at it
- [ ] Test: trigger a real state change on each of the three agents, confirm the
      webhook POST actually arrives — this is what turns "config CRUD works" into
      "notifications actually work," per the gap flagged when this architecture was
      first reviewed

### Phase 7 — Orchestrator
Ballerina · `ballerina/ai` · `ballerina/a2a` client

- [ ] Five tool functions, each resolving its target agent's card once and holding a
      reusable `ballerina/a2a` `Client`
- [ ] **Test each tool directly, bypassing the LLM** — call each tool function in a
      Ballerina test, confirm it correctly reaches its agent and returns a sane result.
      This is the bulk of the orchestrator's real verification, and needs no API key.
- [ ] Wire the five tools into a `ballerina/ai` `Agent` (routing decision layer) —
      structurally complete, but real routing-quality verification waits for Phase 9
- [ ] Push-notification webhook receiver wired in (Phase 6)

### Phase 8 — Local integration & smoke test (the "rough check" pass)
- [ ] All five agents + orchestrator started as local processes on fixed ports
      (matching this project's existing reference-agent pattern)
- [ ] `a2a-smoke-test` skill run: every one of the 11 operations, across all three
      transport bindings, exercised end-to-end against the running system
- [ ] Manual walkthrough: a few real employee-style requests typed by hand against
      the orchestrator, one per agent, confirming routing and responses look sane
      even with the stub model still in place (routing may be naive/rule-based at
      this stage — that's expected, real routing quality is Phase 9)

**Done when:** the whole system runs locally, every op passes the smoke test, no
API key has been spent.

### Phase 9 — Real-key pass (deferred, rate-limited)
Only once the Anthropic key is supplied.

- [ ] Swap every stub model for the real Anthropic client, one agent at a time
- [ ] Run a **fixed, pre-scripted** set of end-to-end scenarios exactly once each —
      write the exact prompts/scenarios down in `DEMO_SCRIPT.md` *before* running
      them, so there's no ad-hoc repeated querying against the real API
- [ ] Confirm orchestrator routing quality with the real model across all five agents
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
- [ ] Re-run the Phase 8 smoke test against the containerized version, confirm parity
      with the local-process version

### Phase 13 — Final polish
- [ ] Full walkthrough rehearsal against `DEMO_SCRIPT.md`
- [ ] Anything cosmetic (WSO2 naming still pending, README polish) closed out

## Testing philosophy summary

| Layer | What it proves | Needs real LLM key? |
|---|---|---|
| Per-agent A2A conformance | Agent card, transport binding, task lifecycle, push notifications | No |
| Orchestrator tool functions | Each tool correctly calls its agent via `ballerina/a2a` | No |
| Local smoke test (Phase 8) | All 11 ops, all 3 transports, end-to-end | No |
| Orchestrator routing quality | The LLM actually picks the right specialist | Yes (Phase 9 only) |
| Negative/chaos testing | Graceful failure under malformed input and load | No |

Everything except one narrow layer is verifiable with zero API spend — the real key
only has to prove one thing at the end, deliberately and a small number of times.

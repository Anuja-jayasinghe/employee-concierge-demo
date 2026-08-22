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

- [ ] `AgentExecutor` wrapping a real ADK agent, configured against the real
      Anthropic model from the start — no interim fake implementation
- [ ] `sendMessage` — FAQ answers (VPN, password reset)
- [ ] Task lifecycle: hardware/ticket request (`getTask`/`cancelTask`/`listTasks`)
- [ ] `sendStreamingMessage` + `subscribeToTask` — live incident investigation,
      genuinely droppable and resumable (test by killing the client connection
      mid-stream and resubscribing, not just letting one stream run uninterrupted)

**Test:**
- [ ] Buildable and code-complete now; agent-card resolution is checkable without
      the key (static data, no LLM call)
- [ ] **Full functional testing — task lifecycle, streaming, `ballerina/a2a` coverage
      of every op in DigiOps's "Proves" list — happens in Phase 9**, since invoking
      this agent's actual message handling means invoking the real model

### Phase 3 — PeopleOperations Agent (HR)
Python · LangGraph · a2a-python SDK · JSON-RPC binding · real Anthropic backing

- [ ] `AgentExecutor` wrapping a real LangGraph graph on `ChatAnthropic` from the start
- [ ] `sendMessage` — policy Q&A
- [ ] `sendStreamingMessage` + `subscribeToTask` — onboarding checklist, multi-step,
      streamed live, genuinely reconnectable (same rigor as DigiOps's stream test)
- [ ] `getExtendedAgentCard` — a staff-only "case escalation" skill present only on
      the authenticated extended card, absent from the public one

**Test:**
- [ ] Agent-card resolution and the public-vs-extended-card diff are checkable now
      (no LLM call involved)
- [ ] **Full functional testing — onboarding stream, reconnect, `ballerina/a2a`
      coverage of every op — happens in Phase 9**

### Phase 4 — Payroll Agent
Java · a2a-java SDK · Quarkus · gRPC binding · real Anthropic backing (via `langchain4j-anthropic`)

- [ ] `AgentExecutor` (a2a-java), real Anthropic model from the start, same pattern
      already proven on `dice_agent` earlier in this project
- [ ] Task lifecycle: payslip-correction request (`getTask`/`cancelTask`/`listTasks`)
- [ ] Full push-notification CRUD — all four operations (this is the one agent proving
      `listTaskPushNotificationConfigs`, the least-covered op elsewhere)
- [ ] `getExtendedAgentCard` — admin-only "adjust another employee's payroll" skill

**Test:**
- [ ] Agent-card resolution checkable now. Push-notification config CRUD is pure data
      storage (create/get/list/delete a config record) with no LLM involvement, so
      it's testable now too, ahead of the key
- [ ] **Task-lifecycle functional testing (`getTask`/`cancelTask`/`listTasks` driven by
      an actual message) happens in Phase 9**, via `ballerina/a2a`'s `GrpcClient`

### Phase 5 — Travel & Expense Agent
Java · a2a-java SDK · REST binding · real Anthropic backing

- [ ] Task lifecycle: expense claim (`getTask`/`cancelTask`/`listTasks`)
- [ ] Push notification config: create + get

**Test:**
- [ ] Agent-card resolution and push-notification config CRUD checkable now
- [ ] **Task-lifecycle functional testing happens in Phase 9**, via `ballerina/a2a`'s `RestClient`

### Phase 6 — Push-notification webhook receiver
- [ ] Minimal HTTP endpoint the orchestrator hosts
- [ ] Payroll, Parking, and Travel & Expense's registered configs point at it
- [ ] Test: trigger a real state change on each of the three agents, confirm the
      webhook POST actually arrives — this is what turns "config CRUD works" into
      "notifications actually work," per the gap flagged when this architecture was
      first reviewed

### Phase 7 — Orchestrator
Ballerina · `ballerina/ai` · `ballerina/a2a` client · real Anthropic backing

- [ ] Five tool functions, each resolving its target agent's card once and holding a
      reusable `ballerina/a2a` `Client`
- [ ] Each tool function is code-complete and calls its real target agent via real
      `ballerina/a2a` — no bypass. Against Parking specifically (the one agent that
      doesn't need the key to run), this is fully testable now
- [ ] Wire the five tools into a real `ballerina/ai` `Agent` (routing decision layer)
      on the real Anthropic model — code-complete now, but actually invoking it means
      invoking the real model, so full routing verification happens in Phase 9
- [ ] Push-notification webhook receiver wired in (Phase 6)

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

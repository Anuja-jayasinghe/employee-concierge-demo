# A2A Capability Coverage

What this multi-agent use-case actually tests and demonstrates of the A2A
protocol and the `ballerina/a2a` client, and — just as deliberately —
what it doesn't, and why. Not a pros/cons list: everything here is a real
capability of the spec or the client, marked against real evidence for
whether this specific system exercises it. "Not demoed" is not a defect
in every row below; several are genuine, permanent scope boundaries for a
five-agent internal-tools demo, spelled out as such rather than left
implicit.

Companion to [`DEMO_SCRIPT.md`](DEMO_SCRIPT.md), which is the presenter's
script for everything in the first section below. This document is the
fuller picture, including the parts that don't make it into a live demo.

## BI chat vs. terminal — since the live demo runs through BI chat

The main demonstration goes through WSO2 Integrator: BI's chat window
against the orchestrator, not a terminal. That's a real constraint worth
being explicit about: BI chat can only show what the orchestrator's own
LLM tool-calling layer actually exposes —
`orchestrator/agent_tools.bal` calls exactly 4 operations
(`sendMessage`, `getTask`, `cancelTask`, `listTasks`), confirmed by
grepping it directly. Everything else in the "fully covered" table below
is real and demoed, but needs a terminal running one of the
`verification/`/`demo/` scripts instead — BI chat will never show it, not
because it doesn't work, but because nothing wires it into that
particular interface. Each row below says which.

## Fully covered — tested and demoed live

| Capability | Via BI chat? | Evidence |
|---|---|---|
| `sendMessage` — plain-message FAQ replies | **Yes** | `DEMO_SCRIPT.md` Act 1 — type the question into BI chat |
| `sendMessage` — task-creating, real long-running lifecycle (staged work, honest in-progress status, real completion) | **Yes** | `DEMO_SCRIPT.md` Act 2 — one example per agent, all through chat |
| `getTask` — status polling within a chat turn | **Yes** | `DEMO_SCRIPT.md` Act 2 — `sendToAgent` polls `getTask` inside the same turn, bounded ~20s |
| `cancelTask` — mid-flight cancel | **Yes** | `DEMO_SCRIPT.md` Act 3 — ask to cancel a task you just started |
| `listTasks` — concurrent, independently-tracked tasks | **Yes** | `DEMO_SCRIPT.md` Act 4 — ask about "all my tasks"; `demo/concurrent_tasks/main.bal` is the fuller, scripted proof of the same real mechanism |
| All 3 transport bindings (REST, JSON-RPC, gRPC) | **Yes, indirectly** | Chat itself doesn't know about transports, but talking to all 5 real agents through it naturally exercises all 3 — Parking/TravelExpense (REST), DigiOps/PeopleOperations (JSON-RPC), Payroll (gRPC) |
| `TaskState`: `SUBMITTED`, `WORKING`, `COMPLETED`, `CANCELED`, `INPUT_REQUIRED` | **Yes** | Reached naturally by the chat-driven rows above |
| `sendStreamingMessage`/`subscribeToTask` (streaming) | **No** | `ballerina/ai` (what the orchestrator's chat agent runs on) doesn't support streaming yet — real framework limitation, not a choice. Terminal instead: `verification/phase9_smoke_test`, `verification/digiops` |
| Push-notification config CRUD + real delivery to a real webhook | **No** | Needs a persistent channel to push a notification into; BI chat is one stateless HTTP request per turn with nothing open in between. Terminal instead: `verification/webhook_receiver` |
| Extended-card auth gating (2 real mechanisms: gRPC interceptor, bearer token) | **No** | Needs a credential (bearer token / gRPC auth header) supplied at client-construction time — no field in a chat message can carry that. Terminal instead: `verification/payroll`, `verification/peopleoperations` |
| Connection-drop recovery — real deliberate disconnect + `subscribeToTask` resume, live | **No** | Needs direct control over the actual stream object to close it mid-flight; a chat message can't reach into that. Terminal instead: `verification/digiops` |
| Automatic reconnect-with-budget mechanism | **No** | Same reason — also only exercised against `a2a-ballerina`'s own mock server, not a live chat agent. Terminal instead: 9 real tests in `a2a-ballerina` |
| Chaos/error handling (malformed requests, 20x concurrent load, resource-leak sanity) | **No** | An LLM building a tool call always produces a well-formed message — there's no way to ask it in English for malformed bytes, and "20 at once" needs real concurrent code, not one message at a time. Terminal instead: `verification/chaos_test` |
| A real spec-vs-server interop bug, found and fixed (content-type negotiation) | **Invisible either way** | Not something you *see* in chat or a script — it's inside every real REST call TravelExpense's Act 2 chat exchanges already make; the fix just means those calls keep working. Story: `docs/research/a2a-client-and-demo-round-check.md` |

**Summary**: 6 of the rows above (everything through `listTasks`) are real,
live, BI-chat-demoable today. The other 7 are just as real, just not
reachable from that specific interface — each has its own terminal
command in `DEMO_SCRIPT.md` Acts 5–7.

## Real capability, reachable in this demo, but not featured in the live script

These aren't gaps — the code path is real and live-triggerable today —
they're just not part of the happy-path narrative `DEMO_SCRIPT.md` walks
through.

| Capability | Real evidence it's reachable | Why not in the script |
|---|---|---|
| `TaskState.FAILED` | `agents/digiops/agent_executor.py:187,215`, `agents/parking/agent_executor.py:66`, `TravelExpenseAgentExecutorProducer.java:99,158`, `PayrollAgentExecutorProducer.java:99,150` — every agent has a real path to it (LLM produces no usable response, or a tool call genuinely errors) | Needs a real failure to trigger on demand; not something to force artificially just to check a box in a live presentation |
| `TaskState.REJECTED` | `agents/parking/agent_executor.py:107` — fires for real when `is_free(spot, date)` is false (a genuine double-booking) | Trivially demoable (reserve the same spot twice) but not currently in the script — worth adding if a presenter wants one more real state transition |
| JWS/JCS AgentCard signature verification | `a2a-ballerina/ballerina/signature.bal` — real RS256/ES256 verification against RFC 8785 JCS canonicalization, tested against real `a2a.js`-produced signatures (`README.md:108-111`) | None of the 5 demo agents' cards carry a real signature — this is an `a2a-ballerina`-library-level feature, exercised only in that repo's own test suite, never wired into this demo |

## Real client/spec capability, zero real usage anywhere in this demo

Genuine, deliberate scope boundaries — these are things a five-agent
internal-tools demo has no real reason to need, not things that were
attempted and fell short.

| Capability | What's real | Why zero usage here |
|---|---|---|
| Formal `securitySchemes` (AgentCard's 5-member auth-scheme union: apiKey, http, oauth2, openIdConnect, mutualTLS) | The client fully parses all 5 scheme types over both REST/JSON and gRPC wire form (`types.bal:706-910`, `grpc_binding.bal:616-683`) | None of the 5 agents declare one — Payroll's gRPC interceptor and PeopleOperations' bearer-token gate are both real, but purely application-level, never advertised via the card's formal auth-scheme field. This demo proves manual, out-of-band auth works; it doesn't prove the discover-a-scheme-and-authenticate-automatically flow, because nothing here implements the server side of that flow either |
| mTLS | `MutualTlsSecurityScheme` is fully typed; the client has no higher-level helper beyond what `http:ClientConfiguration.secureSocket` already provides generically | Documented, permanent, tracked limitation — not silently missing. See `a2a-ballerina/README.md:180-185` and issue #13 |
| `Part` types beyond text (`file`, `data`) | The client's `Part` union and all 3 transport bindings support them structurally | All 26 real `Part` constructions across all 5 agents are `TextPart`/`new_text_part` — every message in this whole system is plain text. No business scenario here (parking, IT tickets, HR, payroll, expenses) genuinely needs a file attachment or structured-data part today |
| Multi-tenancy (`tenant` param) | Every client class (`RestClient`/`JsonRpcClient`/`GrpcClient`) accepts a real `tenant` param and path-prefixes REST requests with it | This demo is a single WSO2-internal deployment — zero real multi-tenant requirement, zero usage anywhere in `orchestrator/`, `demo/`, or `verification/` |
| Extensions (`A2A-Extensions` header / `requestedExtensions`) | Real on all 3 transports (`jsonrpc_client.bal:136-137`, `grpc_client.bal:152-153`, `rest_client.bal:264-265`) | No real extension URI is defined for any of the 5 agents to declare or request — tested only against `a2a-ballerina`'s own mock server, never demoed live |
| A2A v0.3 backward compatibility (`compat_v03.bal`) | Real, client-tested translation layer | All 5 real agents are confirmed v1.0-only (Python `a2a-sdk` 1.1.0, Java `a2a.sdk.v1.version` 1.1.0.Final) — no v0.3 server exists anywhere in this demo to exercise it against |
| `getTask`'s `historyLength` param | Real, typed parameter on every client | `orchestrator/agent_tools.bal`'s two `getTask` call sites both omit it — every real call in this demo uses the default |
| Task/message `metadata` field | Real, typed `map<json>` field throughout | No agent or orchestrator code path in this demo ever sets or reads a real value into it — every call site passes `null` or omits it |

## Genuine capability gap

| Capability | Status |
|---|---|
| `TaskState.AUTH_REQUIRED` | Zero real usage anywhere. `requiresAuth()` exists as a real method on the Java SDK's `AgentEmitter` (confirmed via `javap` decompilation earlier this session), but no business logic in any of the 5 agents ever calls it. Unlike the other rows above, this isn't a "no real reason to need it" scope boundary — an agent that itself required step-up authentication mid-task is a real, plausible scenario this demo's business domains just never happened to need. Worth building if a future scenario calls for it |

## Not a real capability at all — checked, not assumed

**Task queuing.** The A2A v1.0.0 spec's `TaskState` enum has no `QUEUED`
value, and no agent in this demo implements admission control. What's
real and demoed instead: multiple genuinely concurrent, independently
tracked tasks by task id (`DEMO_SCRIPT.md` Act 4) — checked directly
against the spec and the codebase before deciding this, not assumed
because "queuing" sounded like something a task-based protocol should
have.

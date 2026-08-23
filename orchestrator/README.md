# Orchestrator

WSO2 Employee Concierge orchestrator. Currently just the push-notification
webhook receiver (Phase 6) — Phase 7 adds the AI/tool-calling routing
logic into this same package, since the real orchestrator process needs
to host both the outbound agent-calling logic and this inbound receiver.

## Stack

Ballerina · `ballerina/http` · port **9090**.

## Run it

```sh
cd orchestrator
bal run --sticky
```

## What it does

- **`POST /webhooks/push`** — accepts a real push-notification delivery
  from any agent's `PushNotificationSender`. Handles both wire shapes
  seen in this demo: a2a-java's flat `{"id": ..., "status": {...}}`, and
  a2a-python's `StreamResponse`-enveloped `{"task": {...}}` /
  `{"statusUpdate": {...}}`. Logs each real delivery (task ID,
  `status.state`, `X-A2A-Notification-Token`) into an in-memory list.
- **`GET /webhooks/received`** — returns everything received so far, as
  JSON. Real introspection, not a mock — used by
  `verification/webhook_receiver` to assert delivery actually happened.

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

## Verification

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

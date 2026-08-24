# Agent cheat sheet

What each of the five agents behind the orchestrator can actually do,
in plain language — for figuring out what to ask when demoing or
testing the chat.

## What changed

Every write action (reserving parking, raising a ticket, filing a
correction or claim) now asks for the employee's real name if it
doesn't already have one, and remembers it for the rest of the
conversation. Once given, that name is really stored and really
answerable back — "who reserved spot A02?", "who raised that ticket?"
now get real answers instead of a privacy refusal.

The chat used to only be able to send a message and get a reply — no
cancelling, no checking status, no listing. That's fixed too: every
agent now has real cancel/status/list tools wired into the chat, on
top of the original ask tool. When a request creates something, the
reply includes a real task id; mention it back later ("cancel that",
"check on it") and the chat will recall it and act on the real thing.

One real limit worth knowing: "list" shows *every* task that agent has
ever seen, not filtered to just you — there's no login/identity
concept, just whatever name was given per request. In a single-person
demo that's effectively fine, but it's "everyone's," not "yours."

Also still true: push notifications ("let me know when it's approved")
aren't a chat capability — that needs a webhook target of your own.

## A real, disclosed reliability quirk

The chat can occasionally re-call an agent's tool several times for one
simple question, even when the first call already had a clear answer —
confirmed non-deterministic and not fixable by prompt wording alone
(reproduced it down to a single tool and a one-sentence prompt and it
still happened sometimes). Switching from twenty named tools to five
generic ones (see `orchestrator/README.md`) measurably reduced how
often this happens in re-testing, but didn't fully eliminate it — real
architecture details in
[GitHub issue #24](https://github.com/Anuja-jayasinghe/employee-concierge-demo/issues/24).
There's a bounded retry cap in place so a bad run fails fast with a
clear error instead of hanging indefinitely; if a question fails this
way, just ask it again.

---

## Parking
Spot availability and reservations at WSO2 Colombo HQ.

✅ Ask:
- "is anything free?" / "is there any parking available?"
- "is spot A01 free?"
- "reserve spot A01" (it'll ask your name first, if it doesn't have it)
- "reserve me a spot on level 2" (it'll ask which exact spot too)
- "who reserved spot A02?"
- "cancel that" (right after a reservation, in the same conversation)
- "what have I reserved so far?" (lists every reservation attempt, not just yours)

❌ Can't:
- Reserve more than one spot in a single message
- Cancel a reservation that's already gone through — only a still-pending one

---

## DigiOps (IT Helpdesk)
VPN, password resets, hardware requests, and IT incidents.

✅ Ask:
- "how do I reset my VPN password?"
- "I need a new laptop charger" (asks your name, then opens a real ticket with an ID)
- "who raised ticket X?"
- "what's the status of that ticket?" (recalls the id from the conversation)
- "cancel that ticket"
- "my laptop can't reach the internal network" (investigates, gives a diagnosis)
- "what tickets have been raised?" (lists every one this agent knows about)

❌ Can't:
- Anything outside IT (payroll, parking, etc.) — the orchestrator won't route it here anyway

---

## PeopleOperations (HR)
Leave policy, benefits, and new-hire onboarding.

✅ Ask:
- "how many annual leave days do I have?"
- "what benefits am I eligible for?"
- "onboard Jane Doe as a new hire" (already required a name before this change — runs a real multi-step provisioning flow)
- "what's the status of that onboarding?" / "cancel it"
- "what onboardings have been run?"

❌ Can't:
- Escalate a case to a human — that skill exists on the agent but needs a
  staff login token the orchestrator doesn't have, so it's invisible from chat

---

## Payroll
Payslip questions and corrections.

✅ Ask:
- "when is the next pay date?"
- "my payslip has the wrong amount" (asks your name, then files a real correction request with an ID)
- "what's the status of my correction?" / "cancel it"
- "what corrections have been filed?"

❌ Can't:
- Adjust someone *else's* payroll — that's an admin-only skill the orchestrator
  can't unlock (needs an admin token it doesn't have)

---

## Travel & Expense
Travel policy questions and expense claims.

✅ Ask:
- "what's the per-diem rate?"
- "I spent $50 on a taxi for a client meeting" (asks your name, then files a real claim with an ID)
- "what's the status of my claim?" / "cancel it"
- "what claims have been filed?"

❌ Can't:
- Anything about actual travel booking (flights, hotels) — this agent only handles
  policy questions and expense claims, not booking

---

## One more thing

All the data behind these agents (spots, tickets, payslips, claims,
and now names) is fake and lives in memory — it resets every time an
agent restarts. This is a demo, not a connection to any real WSO2
system.

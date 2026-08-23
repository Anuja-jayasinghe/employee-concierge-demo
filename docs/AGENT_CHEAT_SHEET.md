# Agent cheat sheet

What each of the five agents behind the orchestrator can actually do,
in plain language — for figuring out what to ask when demoing or
testing the chat.

## What changed

The chat used to only be able to send a message and get a reply — no
cancelling, no checking status, no listing. That's fixed: every agent
now has real cancel/status/list tools wired into the chat, on top of
the original ask tool. When a request creates something (a
reservation, a ticket, a claim), the reply includes a real task id;
mention it back later ("cancel that", "check on it") and the chat will
recall it from the conversation and act on the real thing, not a
guess.

One real limit worth knowing: "list" shows *every* task that agent has
ever seen, not filtered to just you — there's no login/identity
concept here. In a single-person demo that's effectively the same
thing, but it's not really "yours," it's "everyone's."

Also still true: push notifications ("let me know when it's approved")
aren't a chat capability — that needs a webhook target of your own, not
something a chat reply can set up for you.

---

## Parking
Spot availability and reservations at WSO2 Colombo HQ.

✅ Ask:
- "is anything free?" / "is there any parking available?"
- "is spot A01 free?"
- "reserve spot A01"
- "reserve me a spot on level 2" (it'll ask which exact spot)
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
- "I need a new laptop charger" (opens a real ticket, gives you an ID)
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
- "onboard Jane Doe as a new hire" (runs a real multi-step provisioning flow)
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
- "my payslip has the wrong amount" (files a real correction request, gives an ID)
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
- "I spent $50 on a taxi for a client meeting" (files a real claim, gives an ID)
- "what's the status of my claim?" / "cancel it"
- "what claims have been filed?"

❌ Can't:
- Anything about actual travel booking (flights, hotels) — this agent only handles
  policy questions and expense claims, not booking

---

## One more thing

All the data behind these agents (spots, tickets, payslips, claims) is
fake and lives in memory — it resets every time an agent restarts. This
is a demo, not a connection to any real WSO2 system.

# Agent cheat sheet

What each of the five agents behind the orchestrator can actually do,
in plain language — for figuring out what to ask when demoing or
testing the chat.

## The one big limitation, for all five agents

The chat can only **send a message and get a reply back**. Each agent
really does support cancelling a task, checking a task's status by ID,
and (for some) push notifications — but the orchestrator's chat tools
only ever call `sendMessage`, so none of that is reachable from chat.
If you ask to "cancel my reservation" or "check on task X", it won't
work, no matter which agent you're talking to.

---

## Parking
Spot availability and reservations at WSO2 Colombo HQ.

✅ Ask:
- "is anything free?" / "is there any parking available?"
- "is spot A01 free?"
- "reserve spot A01"
- "reserve me a spot on level 2" (it'll ask which exact spot)

❌ Can't:
- List spots *you* reserved — there's no concept of "you," just spot IDs
- Reserve more than one spot in a single message

---

## DigiOps (IT Helpdesk)
VPN, password resets, hardware requests, and IT incidents.

✅ Ask:
- "how do I reset my VPN password?"
- "I need a new laptop charger" (opens a real ticket, gives you an ID)
- "what's the status of ticket <id>?"
- "my laptop can't reach the internal network" (investigates, gives a diagnosis)

❌ Can't:
- List every ticket you've ever raised — you need the specific ticket ID
- Anything outside IT (payroll, parking, etc.) — the orchestrator won't route it here anyway

---

## PeopleOperations (HR)
Leave policy, benefits, and new-hire onboarding.

✅ Ask:
- "how many annual leave days do I have?"
- "what benefits am I eligible for?"
- "onboard Jane Doe as a new hire" (runs a real multi-step provisioning flow)

❌ Can't:
- Escalate a case to a human — that skill exists on the agent but needs a
  staff login token the orchestrator doesn't have, so it's invisible from chat
- Track or list onboardings you've already run

---

## Payroll
Payslip questions and corrections.

✅ Ask:
- "when is the next pay date?"
- "my payslip has the wrong amount" (files a real correction request, gives an ID)
- "what's the status of correction <id>?"

❌ Can't:
- Adjust someone *else's* payroll — that's an admin-only skill the orchestrator
  can't unlock (needs an admin token it doesn't have)
- List every correction you've filed — you need the specific ID

---

## Travel & Expense
Travel policy questions and expense claims.

✅ Ask:
- "what's the per-diem rate?"
- "I spent $50 on a taxi for a client meeting" (files a real claim, gives an ID)
- "what's the status of claim <id>?"

❌ Can't:
- List every claim you've filed — you need the specific ID
- Anything about actual travel booking (flights, hotels) — this agent only handles
  policy questions and expense claims, not booking

---

## One more thing

All the data behind these agents (spots, tickets, payslips, claims) is
fake and lives in memory — it resets every time an agent restarts. This
is a demo, not a connection to any real WSO2 system.

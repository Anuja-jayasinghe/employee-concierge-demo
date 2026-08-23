# Demo Script — Phase 9 functional pass

Written before any scenario is run against the real Anthropic API, per the
implementation plan's rule for this phase: script first, execute once.
Results are appended to each scenario after the one real run — see
`RESULT:` lines.

Each scenario is either a direct call to one agent (proving that agent's
own real content) or a natural-language request through the orchestrator
(proving real routing quality — does the concierge Agent pick the right
tool). Executed by `verification/phase9_smoke_test/main.bal`.

## Direct-to-agent scenarios

### 1. DigiOps — IT policy FAQ
**Request:** "what's the password policy?"
**Expected:** a real answer referencing the system prompt's reference
facts (minimum length, rotation period, self-service reset).

### 2. DigiOps — incident investigation (streaming)
**Request:** "I can't reach the internal wiki, is there an outage?"
**Expected:** the staged investigation narration (`Checking network
logs...`, `Correlating with recent infrastructure changes...`) streamed
first, then a real diagnosis from the model.

### 3. PeopleOperations — HR policy FAQ
**Request:** "how many annual leave days do I get?"
**Expected:** a real answer referencing the 20-day reference fact.

### 4. PeopleOperations — onboarding (streaming, real tool calls)
**Request:** "please start onboarding for a new hire named Nadeesha
Perera"
**Expected:** real tool calls to `provision_laptop`, `assign_desk`,
`enroll_benefits` narrated live via streaming, ending in a completed task.

### 5. Payroll — payslip correction (real tool call, gRPC)
**Request:** "my payslip shows the wrong tax deduction, please file a
correction"
**Expected:** a real `fileCorrectionRequest` tool call, a real correction
ID returned in the response.

### 6. Travel & Expense — expense claim (real tool call, REST)
**Request:** "I need to claim LKR 8000 for a client dinner in Colombo"
**Expected:** a real `fileExpenseClaim` tool call, a real claim ID
returned in the response.

## Orchestrator routing scenarios

Same five requests' domains, phrased naturally, sent to the orchestrator's
`concierge` Agent — not the target agent directly. Confirms the real
model picks the right one of the five tools each time.

### 7. Routes to Parking
**Request:** "is there a free parking spot at HQ right now?"
**Expected:** `askParkingAgent` called; a real answer from Parking (no
key needed on Parking's side, but the routing decision itself is real).

### 8. Routes to DigiOps
**Request:** "my laptop won't connect to the VPN, can you help?"
**Expected:** `askDigiOpsAgent` called; a real IT answer.

### 9. Routes to Payroll
**Request:** "when do I get paid this month?"
**Expected:** `askPayrollAgent` called; a real payroll answer.

### 10. Off-domain request — should decline rather than guess
**Request:** "what's the weather like today?"
**Expected:** the concierge declines or says this doesn't match any of
its five domains, rather than calling a tool anyway.

// Real bal test suite exercising the five tool functions directly — no
// mocks. Start all five real agent processes before running `bal test`:
// each tool holds a real ballerina/a2a Client, and module init itself
// resolves all five real Agent Cards, so the whole test package fails to
// even start if any target agent isn't reachable (see agent_tools.bal).
//
// Against Parking specifically (needs no Anthropic key), the reply is
// asserted for real content. The other four need a real key to answer
// meaningfully; without one, they're asserted to fail gracefully — proof
// the tool -> ballerina/a2a -> real agent wire is genuinely connected,
// not a bypass.
import ballerina/test;

@test:Config {}
function testAskParkingAgentReturnsARealAnswer() returns error? {
    string reply = check askParkingAgent("is spot A03 available?");
    test:assertTrue(reply.length() > 0, "expected a non-empty real reply from Parking");
}

@test:Config {}
function testAskDigiOpsAgentFailsGracefullyWithoutAKey() returns error? {
    string|error result = askDigiOpsAgent("how do I reset my VPN password?");
    test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
}

@test:Config {}
function testAskPeopleOperationsAgentFailsGracefullyWithoutAKey() returns error? {
    string|error result = askPeopleOperationsAgent("how many annual leave days do I have?");
    test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
}

@test:Config {}
function testAskPayrollAgentFailsGracefullyWithoutAKey() returns error? {
    string|error result = askPayrollAgent("when is the next pay date?");
    test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
}

@test:Config {}
function testAskTravelExpenseAgentFailsGracefullyWithoutAKey() returns error? {
    string|error result = askTravelExpenseAgent("what's the per-diem rate?");
    test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
}

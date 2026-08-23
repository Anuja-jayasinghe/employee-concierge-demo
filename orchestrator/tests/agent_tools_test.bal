// Real bal test suite exercising the five tool functions directly — no
// mocks. Start all five real agent processes before running `bal test`:
// each tool holds a real ballerina/a2a Client, and module init itself
// resolves all five real Agent Cards, so the whole test package fails to
// even start if any target agent isn't reachable (see agent_tools.bal).
//
// Against Parking specifically (needs no Anthropic key), the reply is
// always asserted for real content. The other four need a real key to
// answer meaningfully: with ANTHROPIC_API_KEY unset, they're asserted to
// fail gracefully — proof the tool -> ballerina/a2a -> real agent wire is
// genuinely connected, not a bypass. With a real key present (Phase 9),
// they're asserted for real, non-empty content instead — see
// docs/DEMO_SCRIPT.md for the actual real answers these produced.
import ballerina/os;
import ballerina/test;

final boolean hasRealKey = os:getEnv("ANTHROPIC_API_KEY") != "";

@test:Config {}
function testAskParkingAgentReturnsARealAnswer() returns error? {
    string reply = check askParkingAgent("is spot A03 available?");
    test:assertTrue(reply.length() > 0, "expected a non-empty real reply from Parking");
}

@test:Config {}
function testAskDigiOpsAgent() returns error? {
    string|error result = askDigiOpsAgent("how do I reset my VPN password?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testAskPeopleOperationsAgent() returns error? {
    string|error result = askPeopleOperationsAgent("how many annual leave days do I have?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testAskPayrollAgent() returns error? {
    string|error result = askPayrollAgent("when is the next pay date?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testAskTravelExpenseAgent() returns error? {
    string|error result = askTravelExpenseAgent("what's the per-diem rate?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

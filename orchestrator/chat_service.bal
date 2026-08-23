// Exposes `concierge` as a chat-testable service. Without this, the
// package's only `service` is webhook_receiver.bal's plain http:Listener,
// so BI's Visualizer renders that as the Design canvas's entry point and
// shows the five a2a:Client tool targets as generic Connection nodes —
// there's no ai:Listener/ChatService for it to recognize as an AI Agent
// with a chat panel to test against. `ai:Listener` + a `chat` resource
// calling `concierge.run(...)` is the real, confirmed shape BI itself
// generates for this (see docs/research/wso2-integrator-bi-compatibility.md
// and ~/WSO2Integrator/wso2-integrator-a2a/a2ademoassistant/main.bal, a
// real BI-scaffolded project on this machine using the identical pattern).
import ballerina/ai;
import ballerina/http;

// A nested agent call (concierge picks among its tools, calls a
// downstream agent, which runs its own real LLM call and replies) can
// genuinely take longer than http:Listener's 30s default timeout,
// especially with 20 tool definitions in concierge's own prompt now
// instead of 5 -- reproduced this as a real "Idle timeout triggered
// before initiating outbound response" failure. 120s covers a slow
// double round-trip with real margin.
listener http:Listener chatHttpListener = new (8090, timeout = 120);
listener ai:Listener chatListener = new (chatHttpListener);

service /concierge on chatListener {

    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string result = check concierge.run(request.message, request.sessionId);
        return {message: result};
    }
}

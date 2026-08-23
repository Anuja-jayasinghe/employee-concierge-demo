# WSO2 Integrator: BI compatibility

**Question:** the demo's primary use case is presenting through WSO2
Integrator: BI's low-code tooling, not a terminal or Docker. Is
`orchestrator/` — a plain Ballerina package built with the `bal` CLI, not
created via BI's own project wizard — actually compatible with it?

**Method:** no guessing. Installed/inspected the real VS Code extensions
already present on the machine, read their actual manifests and bundled
code, and opened the real `orchestrator/` package in VS Code with them
active.

## What BI actually is

`wso2.wso2-integrator` (v1.0.1) and `wso2.ballerina` (v5.12.5) were
already installed. Their `package.json` manifests are unambiguous:

```json
"activationEvents": [
  "onStartupFinished",
  "workspaceContains:**/Ballerina.toml",
  "onLanguage:ballerina",
  ...
]
```

Both extensions activate on `workspaceContains:**/Ballerina.toml` — a
plain, standard Ballerina package trigger, not a proprietary project
format. `wso2.wso2-integrator`'s `displayName` is "WSO2 Integrator" and
it bundles **two** modes in one extension: "BI" (Ballerina Integrator,
the low-code AI-agent tooling) and "MI" (Micro Integrator, WSO2's older,
separate ESB product) — confirmed by the command list:

```
wso2.integrator.openBIIntegration - Open Default Integration
wso2.integrator.openMIIntegration - Open MI Integration
ballerina.showVisualizer - Show Visualizer
BI.project-explorer.add-function - Add Function
BI.project-explorer.add-connection - Add Connection
```

`ballerina.showVisualizer` — the BI visual designer — is literally a
command on the **base Ballerina extension**, not a separate product.

**Install path** (from BI's own docs, `bi.docs.wso2.com/get-started/install-wso2-integrator-bi/`):
VS Code → install the "WSO2 Integrator: BI" extension from the
marketplace → it automatically installs and configures the standard
Ballerina distribution. BI does not ship its own runtime; it *requires*
and *wraps* the real `bal` toolchain.

## Empirical test

Ran `code -n orchestrator/` (found the real `code` CLI at
`/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`,
not on `PATH` by default) to open the actual repo package. Both
extensions activate on it — no conversion, no wizard, no error.

## Deployment

BI has its own separate Docker/Kubernetes deployment tooling
(`bi.docs.wso2.com/deploy/containerized-deployment/`, a
"Deploy with Docker" button in the Visualizer), independent of the
hand-written `Dockerfile`s and `docker-compose.yml` built in Phase 12.
Both are legitimate, unrelated paths — Phase 12's Docker work doesn't
need BI, and BI's own deployment tooling doesn't need Phase 12's
Dockerfiles.

## Conclusion

`orchestrator/` needs no changes to be compatible with BI. It's a
standard Ballerina package; BI is tooling layered on the standard
Ballerina distribution, not a separate runtime or format. See
[`remote-agent-integration-patterns.md`](remote-agent-integration-patterns.md)
for the follow-up question this raised — how BI expects a remote A2A
agent to be wired into an agent it builds.

## Follow-up: opening it in BI showed the webhook receiver, not a chat agent

The compatibility conclusion above only says BI activates on the
package — it doesn't say what BI's Design canvas actually *shows*. Real
test: opened `orchestrator/` in the BI Visualizer. The canvas rendered
`webhook_receiver.bal`'s plain `http:Listener` (`POST /webhooks/push`,
`GET /webhooks/received`) as the entry point, and the five
`agent_tools.bal` `a2a:Client`s as generic, unlabeled **Connection**
nodes — no "AI Agent Service" node, no chat panel, nothing to test
`concierge` against.

**Root cause, confirmed by reading the actual code**:
`concierge_agent.bal` declares `final ai:Agent concierge = check new (...)`
but nothing in the package ever calls `concierge.run(...)` — no
`ai:Listener`, no `ai:ChatService`. `grep -n "concierge" orchestrator/*.bal`
turns up exactly one line, the declaration itself. BI has nothing to
render as a chat agent because there wasn't one — `concierge` was built
but never actually exposed as a service.

**Confirmed real fix, not a guess**: `ballerina/ai` 1.14.0 (the exact
version this package depends on — checked its own `Ballerina.toml`) ships
a real `ai:Listener` class (`modules/ai/listener.bal`) and `ai:ChatService`
type (`modules/ai/types.bal`, a `chat` resource taking `ChatReqMessage` /
returning `ChatRespMessage`) for exactly this. Found the exact working
pattern in a real, already-installed BI-scaffolded project on this
machine — `~/WSO2Integrator/wso2-integrator-a2a/a2ademoassistant/main.bal`,
BI's own generated code for an equivalent A2A-delegating chat agent:

```ballerina
listener ai:Listener chatAgentListener = new (listenOn = check http:getDefaultListener());

service /assistantAgent on chatAgentListener {
    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string stringResult = check assistantAgent.run(request.message, request.sessionId);
        return {message: stringResult};
    }
}
```

Added the same shape to `orchestrator/chat_service.bal`, wired to
`concierge` on port 8090 at `/concierge/chat`, and verified with a real
`bal build --sticky` that it compiles. See `orchestrator/README.md`'s
"Chatting with it" section for how to use it, from curl or from BI's chat
panel.

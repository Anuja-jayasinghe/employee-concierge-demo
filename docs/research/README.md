# Research

Investigations done outside the numbered implementation-plan phases —
architectural questions that needed real evidence (source code, official
docs, or both) rather than a guess, before a decision got made. Each file
here cites exactly what was checked and where, per the standing rule:
confirm by real evidence, never assume.

| Doc | Question | Outcome |
|---|---|---|
| [`remote-agent-integration-patterns.md`](remote-agent-integration-patterns.md) | How do real frameworks wire a remote/A2A agent into an orchestrator — system-prompt text, or tools? | Tools, universally. Confirmed our existing `orchestrator/agent_tools.bal` already matches — no redesign needed |
| [`wso2-integrator-bi-compatibility.md`](wso2-integrator-bi-compatibility.md) | Is `orchestrator/` (a plain `bal`-CLI Ballerina package) compatible with WSO2 Integrator: BI, the platform this will actually be demoed through? | Yes, confirmed for real — BI is a VS Code extension on the standard Ballerina distribution, not a separate runtime or format |

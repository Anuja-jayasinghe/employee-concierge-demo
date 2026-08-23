# Employee Concierge Demo

End-to-end multi-agent demo for [`ballerina/a2a`](https://github.com/Anuja-jayasinghe/a2a-ballerina) —
one Ballerina orchestrator routing to five independent A2A listener agents,
each in a different language/framework, exercising every operation and
transport binding the client supports.

- [Architecture](docs/architecture.md) — the approved proposal, in full.
- [Implementation plan](docs/implementation-plan.md) — phased build plan, review this.
- [Naming](NAMING.md) — generic names vs. confirmed WSO2 internal names.

Status: Phases 1–8 complete (all five agents, the orchestrator, the
push-notification webhook receiver, and local bring-up). Phase 9 (full
functional pass with a real Anthropic key) is next.

## Running the whole system locally

```sh
./scripts/start-all.sh              # all five agents + the orchestrator
./scripts/run-structural-checks.sh  # every check that doesn't need a real key
./scripts/stop-all.sh
```

Set `ANTHROPIC_API_KEY` before `start-all.sh` for real LLM answers; left
unset, everything still boots and every structural check still passes —
see [the implementation plan](docs/implementation-plan.md)'s Phase 8
entry for what "structural" covers here. `run-structural-checks.sh` may
occasionally report the Payroll/Travel & Expense push-notification
delivery check as failed — that's the real, already-documented
a2a-java race condition from Phase 6 (see `orchestrator/README.md`), not
a bug in these scripts; re-run it and it usually passes within a few
attempts.

Each agent and the orchestrator also has its own README with instructions
to run and verify it individually.

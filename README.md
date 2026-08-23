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
cp .env.example .env   # then fill in a real ANTHROPIC_API_KEY
./scripts/start-all.sh              # all five agents + the orchestrator
./scripts/run-structural-checks.sh  # every check that doesn't need a real key
./scripts/stop-all.sh
```

`.env` (git-ignored) is where the real Anthropic key lives — `start-all.sh`
sources it automatically. Left unset, everything still boots and every
structural check still passes —
see [the implementation plan](docs/implementation-plan.md)'s Phase 8
entry for what "structural" covers here. `run-structural-checks.sh` may
occasionally report the Payroll/Travel & Expense push-notification
delivery check as failed — that's the real, already-documented
a2a-java race condition from Phase 6 (see `orchestrator/README.md`), not
a bug in these scripts; re-run it and it usually passes within a few
attempts.

Each agent and the orchestrator also has its own README with instructions
to run and verify it individually.

## Running the whole system in Docker

Local-process (`scripts/start-all.sh`) and Docker are both fully
supported — Docker is additive, not a replacement.

```sh
./orchestrator/prepare-docker-build.sh   # ballerina/a2a isn't published to
                                          # Central; stages the local build
cp .env.example .env                     # fill in a real ANTHROPIC_API_KEY
docker compose up -d --build
./scripts/docker-verify.sh               # confirms parity with local-process
docker compose down
```

Every agent's own README, and every `verification/*` script, work
unmodified against the containerized system from the host — they hit the
same published `127.0.0.1:PORT`s either way. The one exception is
`verification/docker_parity`, which specifically has to run *inside* the
Compose network (via `scripts/docker-verify.sh`) rather than from the
host, since Compose service names like `parking` only resolve there — see
that script's own comments for why.

### A note on WSO2 Integrator: BI

The orchestrator's own architecture doc originally floated
`ballerina/ai` "(or WSO2 Integrator: BI)" as an alternative. Investigated
this for real rather than guessing: BI is a VS Code extension layered on
the standard Ballerina distribution, not a separate runtime — both it and
the base Ballerina extension activate on `workspaceContains:**/Ballerina.toml`,
a plain package trigger, confirmed by inspecting the installed
extensions' own manifests. `orchestrator/` opens in it with no conversion
needed. BI also has its own separate Docker/Kubernetes deployment
tooling, independent of the Dockerfiles here, if that path is wanted
later.

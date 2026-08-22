from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue


class PeopleOperationsAgentExecutor(AgentExecutor):
    """PeopleOperations Agent (HR) — LangGraph + real Anthropic backing.

    Scaffolding only for now: LangGraph wiring, policy Q&A, onboarding
    streaming, and extended-card gating land in follow-up commits.
    """

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError

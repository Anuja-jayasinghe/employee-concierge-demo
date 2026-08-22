from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue


class DigiOpsAgentExecutor(AgentExecutor):
    """DigiOps Agent (IT Helpdesk) — Google ADK + real Anthropic backing.

    Scaffolding only for now: ADK Runner wiring, FAQ Q&A, ticket lifecycle,
    and streaming incident investigation land in follow-up commits.
    """

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError

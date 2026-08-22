from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue


class ParkingAgentExecutor(AgentExecutor):
    """Parking Manager Agent — no LLM, deterministic logic only.

    Scaffolding only for now: real availability lookup, reservation
    lifecycle, and cancellation land in follow-up commits.
    """

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError

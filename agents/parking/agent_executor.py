from a2a.helpers import get_message_text, new_text_message
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue

from data import find_mentioned_spot

_RESERVE_KEYWORDS = ('reserve', 'book')


class ParkingAgentExecutor(AgentExecutor):
    """Parking Manager Agent — no LLM, deterministic logic only.

    Reservation task lifecycle and cancellation land in follow-up commits;
    this handles the direct availability Q&A path only so far.
    """

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        query = get_message_text(context.message) or ''
        spot = find_mentioned_spot(query)
        wants_reservation = any(k in query.lower() for k in _RESERVE_KEYWORDS)

        if wants_reservation:
            # Reservation task lifecycle lands in a follow-up commit.
            raise NotImplementedError('reservation lifecycle not yet implemented')

        if spot is None:
            reply = (
                "I couldn't find a spot ID in that message — try asking "
                "like \"is spot A01 free?\""
            )
        elif spot.free:
            reply = f'Spot {spot.spot_id} ({spot.level}) is currently free.'
        else:
            reply = f'Spot {spot.spot_id} ({spot.level}) is currently taken.'

        await event_queue.enqueue_event(
            new_text_message(reply, context_id=context.message.context_id)
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError

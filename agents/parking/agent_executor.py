import asyncio

from a2a.helpers import (
    get_message_text,
    new_task_from_user_message,
    new_text_message,
    new_text_part,
)
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater

from data import find_mentioned_spot

_RESERVE_KEYWORDS = ('reserve', 'book')

# How long a reservation stays cancelable before it resolves — long enough
# for a real cancelTask call to land inside the window, short enough not to
# make manual testing annoying.
_CHECK_DELAY_SECONDS = 4

# task_id -> asyncio.Event, set by cancel() to interrupt a pending
# reservation's artificial delay. In-memory only, matches InMemoryTaskStore.
_cancel_signals: dict[str, asyncio.Event] = {}


class ParkingAgentExecutor(AgentExecutor):
    """Parking Manager Agent — no LLM, deterministic logic only."""

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        query = get_message_text(context.message) or ''
        spot = find_mentioned_spot(query)
        wants_reservation = any(k in query.lower() for k in _RESERVE_KEYWORDS)

        if not wants_reservation:
            await self._answer_availability(query, spot, context, event_queue)
            return

        if spot is None:
            await event_queue.enqueue_event(
                new_text_message(
                    "I couldn't find a spot ID in that message — try "
                    '"reserve spot A01"',
                    context_id=context.message.context_id,
                )
            )
            return

        task = new_task_from_user_message(context.message)
        await event_queue.enqueue_event(task)
        updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await updater.submit()
        await updater.start_work(
            message=updater.new_agent_message(
                parts=[new_text_part(f'Checking spot {spot.spot_id} with facilities...')]
            )
        )

        cancel_signal = asyncio.Event()
        _cancel_signals[task.id] = cancel_signal
        try:
            try:
                await asyncio.wait_for(
                    cancel_signal.wait(), timeout=_CHECK_DELAY_SECONDS
                )
                # Signal fired before the timeout: cancel() already handled
                # the task-state transition, nothing left to do here.
                return
            except asyncio.TimeoutError:
                pass  # Not canceled — proceed to resolve the reservation.

            if not spot.free:
                await updater.reject(
                    message=updater.new_agent_message(
                        parts=[new_text_part(f'Spot {spot.spot_id} is already taken.')]
                    )
                )
                return

            spot.free = False
            spot.reserved_by_task_id = task.id
            await updater.complete(
                message=updater.new_agent_message(
                    parts=[new_text_part(f'Spot {spot.spot_id} reserved.')]
                )
            )
        finally:
            _cancel_signals.pop(task.id, None)

    async def _answer_availability(self, query, spot, context, event_queue) -> None:
        if spot is None:
            reply = (
                "I couldn't find a spot ID in that message — try asking "
                'like "is spot A01 free?"'
            )
        elif spot.free:
            reply = f'Spot {spot.spot_id} ({spot.level}) is currently free.'
        else:
            reply = f'Spot {spot.spot_id} ({spot.level}) is currently taken.'

        await event_queue.enqueue_event(
            new_text_message(reply, context_id=context.message.context_id)
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        task = context.current_task
        if task is None:
            return
        signal = _cancel_signals.get(task.id)
        updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await updater.cancel(
            message=updater.new_agent_message(
                parts=[new_text_part('Reservation request canceled.')]
            )
        )
        if signal is not None:
            signal.set()

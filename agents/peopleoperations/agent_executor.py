import asyncio

from a2a.helpers import get_message_text, new_task_from_user_message, new_text_part
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater

from agent import PeopleOperationsAgent

# task_id -> asyncio.Event, set by cancel() to interrupt a pending
# onboarding/policy-Q&A stream between yielded steps. In-memory only.
_cancel_signals: dict[str, asyncio.Event] = {}


class PeopleOperationsAgentExecutor(AgentExecutor):
    """PeopleOperations Agent (HR) — LangGraph + real Anthropic backing.

    Policy Q&A and onboarding share this one streaming code path
    deliberately — the real LLM's own tool-calling (0 tool calls for a
    direct policy answer, 3 in sequence for onboarding) is what
    distinguishes them, not a branch in this executor.
    """

    def __init__(self) -> None:
        self._agent = PeopleOperationsAgent()

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        query = get_message_text(context.message) or ''

        task = context.current_task
        if task is None:
            task = new_task_from_user_message(context.message)
            await event_queue.enqueue_event(task)
        updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await updater.submit()

        cancel_signal = asyncio.Event()
        _cancel_signals[task.id] = cancel_signal
        try:
            async for item in self._agent.stream(query, task.context_id):
                if cancel_signal.is_set():
                    return  # cancel() already handled the task-state transition

                is_task_complete = item['is_task_complete']
                require_user_input = item['require_user_input']

                if not is_task_complete and not require_user_input:
                    await updater.start_work(
                        message=updater.new_agent_message(
                            parts=[new_text_part(item['content'])]
                        )
                    )
                elif require_user_input:
                    await updater.requires_input(
                        message=updater.new_agent_message(
                            parts=[new_text_part(item['content'])]
                        )
                    )
                    return
                else:
                    await updater.add_artifact(
                        parts=[new_text_part(item['content'])]
                    )
                    await updater.complete()
                    return
        finally:
            _cancel_signals.pop(task.id, None)

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        task = context.current_task
        if task is None:
            return
        signal = _cancel_signals.get(task.id)
        updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await updater.cancel()
        if signal is not None:
            signal.set()

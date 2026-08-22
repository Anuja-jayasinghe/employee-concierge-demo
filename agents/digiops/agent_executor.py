import asyncio

from google.adk.runners import Runner
from google.genai import types

from a2a.helpers import get_message_text, new_task_from_user_message, new_text_part
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater

from agent import AgentResponse

_INCIDENT_KEYWORDS = ('incident', 'outage', 'cannot reach', "can't reach", 'down')

# Deterministic, executor-orchestrated progress narration for the incident
# flow — the *diagnosis* itself always comes from a real LLM call; these are
# just the "still working..." steps a real long-running investigation
# would report, staged so cancelTask has real windows to interrupt.
_INVESTIGATION_STEPS = (
    'Checking network logs...',
    'Correlating with recent infrastructure changes...',
)
_STEP_DELAY_SECONDS = 2

# task_id -> asyncio.Event, set by cancel() to interrupt a pending
# incident investigation's staged delays. In-memory only.
_cancel_signals: dict[str, asyncio.Event] = {}


class DigiOpsAgentExecutor(AgentExecutor):
    """DigiOps Agent (IT Helpdesk) — Google ADK + real Anthropic backing."""

    def __init__(self, runner: Runner) -> None:
        self._runner = runner

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        query = get_message_text(context.message) or ''
        is_incident = any(k in query.lower() for k in _INCIDENT_KEYWORDS)

        user_id, session_id = await self._ensure_session(context)
        task = context.current_task
        if task is None:
            task = new_task_from_user_message(context.message)
            await event_queue.enqueue_event(task)
        updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await updater.submit()

        if is_incident:
            await self._run_incident_flow(query, user_id, session_id, updater)
        else:
            await self._run_llm_flow(query, user_id, session_id, updater)

    async def _ensure_session(self, context: RequestContext) -> tuple[str, str]:
        user_id = 'a2a_user'
        session_id = context.message.context_id or context.context_id
        session = await self._runner.session_service.get_session(
            app_name=self._runner.app_name, user_id=user_id, session_id=session_id
        )
        if session is None:
            await self._runner.session_service.create_session(
                app_name=self._runner.app_name, user_id=user_id, session_id=session_id
            )
        return user_id, session_id

    async def _call_llm(
        self, query: str, user_id: str, session_id: str
    ) -> AgentResponse | None:
        """Runs the real ADK Runner and parses its structured response.
        Returns None if the model produced no final response or the
        response didn't parse as the expected schema."""
        content = types.Content(role='user', parts=[types.Part.from_text(text=query)])
        final_text = None
        async for event in self._runner.run_async(
            user_id=user_id, session_id=session_id, new_message=content
        ):
            if event.is_final_response() and event.content and event.content.parts:
                final_text = event.content.parts[0].text

        if final_text is None:
            return None
        try:
            return AgentResponse.model_validate_json(final_text.strip())
        except ValueError:
            return None

    async def _run_llm_flow(
        self, query: str, user_id: str, session_id: str, updater: TaskUpdater
    ) -> None:
        """FAQ Q&A and hardware-ticket handling — both go through the same
        real LLM tool-calling path, so there's no separate code branch for
        the two: the model decides whether to call create_ticket/get_ticket
        or just answer directly."""
        await updater.start_work()
        response = await self._call_llm(query, user_id, session_id)
        await self._resolve_from_response(updater, response)

    async def _run_incident_flow(
        self, query: str, user_id: str, session_id: str, updater: TaskUpdater
    ) -> None:
        """Staged progress narration (deterministic, executor-controlled) is
        purely how a real long-running investigation reports being alive —
        the actual diagnosis at the end always comes from a real LLM call.
        cancelTask can interrupt at any staged step."""
        cancel_signal = asyncio.Event()
        _cancel_signals[updater.task_id] = cancel_signal
        try:
            for step in _INVESTIGATION_STEPS:
                await updater.start_work(
                    message=updater.new_agent_message(parts=[new_text_part(step)])
                )
                try:
                    await asyncio.wait_for(
                        cancel_signal.wait(), timeout=_STEP_DELAY_SECONDS
                    )
                    return  # cancel() already handled the task-state transition
                except asyncio.TimeoutError:
                    pass

            diagnosis_prompt = (
                f'Investigate this reported incident and give a diagnosis '
                f'and next step: {query}'
            )
            response = await self._call_llm(diagnosis_prompt, user_id, session_id)
            await self._resolve_from_response(updater, response)
        finally:
            _cancel_signals.pop(updater.task_id, None)

    async def _resolve_from_response(
        self, updater: TaskUpdater, response: AgentResponse | None
    ) -> None:
        if response is None:
            await updater.failed(
                message=updater.new_agent_message(
                    parts=[new_text_part('No usable response produced.')]
                )
            )
            return

        reply = updater.new_agent_message(parts=[new_text_part(response.message)])
        if response.status == 'completed':
            await updater.add_artifact(parts=[new_text_part(response.message)])
            await updater.complete(message=reply)
        elif response.status == 'input-required':
            await updater.requires_input(message=reply)
        else:
            await updater.failed(message=reply)

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

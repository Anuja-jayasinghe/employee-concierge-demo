from google.adk.runners import Runner
from google.genai import types

from a2a.helpers import get_message_text, new_task_from_user_message, new_text_part
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater

from agent import AgentResponse

_INCIDENT_KEYWORDS = ('incident', 'outage', 'cannot reach', "can't reach", 'down')


class DigiOpsAgentExecutor(AgentExecutor):
    """DigiOps Agent (IT Helpdesk) — Google ADK + real Anthropic backing."""

    def __init__(self, runner: Runner) -> None:
        self._runner = runner

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        query = get_message_text(context.message) or ''

        if any(k in query.lower() for k in _INCIDENT_KEYWORDS):
            # Streaming incident-investigation flow lands in a follow-up commit.
            raise NotImplementedError('incident investigation not yet implemented')

        await self._run_llm_flow(query, context, event_queue)

    async def _run_llm_flow(
        self, query: str, context: RequestContext, event_queue: EventQueue
    ) -> None:
        """FAQ Q&A and hardware-ticket handling — both go through the same
        real LLM tool-calling path, so there's no separate code branch for
        the two: the model decides whether to call create_ticket/get_ticket
        or just answer directly."""
        user_id = 'a2a_user'
        session_id = context.message.context_id or context.context_id

        session = await self._runner.session_service.get_session(
            app_name=self._runner.app_name, user_id=user_id, session_id=session_id
        )
        if session is None:
            await self._runner.session_service.create_session(
                app_name=self._runner.app_name, user_id=user_id, session_id=session_id
            )

        task = context.current_task
        if task is None:
            task = new_task_from_user_message(context.message)
            await event_queue.enqueue_event(task)

        updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await updater.submit()
        await updater.start_work()

        content = types.Content(role='user', parts=[types.Part.from_text(text=query)])

        final_text = None
        async for event in self._runner.run_async(
            user_id=user_id, session_id=session_id, new_message=content
        ):
            if event.is_final_response() and event.content and event.content.parts:
                final_text = event.content.parts[0].text

        if final_text is None:
            await updater.failed(
                message=updater.new_agent_message(
                    parts=[new_text_part('No response produced.')]
                )
            )
            return

        try:
            response = AgentResponse.model_validate_json(final_text.strip())
        except ValueError:
            await updater.failed(
                message=updater.new_agent_message(
                    parts=[new_text_part(final_text)]
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
        updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await updater.cancel()

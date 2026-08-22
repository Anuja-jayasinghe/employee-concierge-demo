from collections.abc import AsyncIterable
from typing import Any, Literal

from langchain_anthropic import ChatAnthropic
from langchain_core.messages import AIMessage, ToolMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.prebuilt import create_react_agent
from pydantic import BaseModel

from tools import assign_desk, enroll_benefits, provision_laptop

memory = MemorySaver()

# Fictional-but-WSO2-styled HR reference facts — no real internal policy or
# figures, consistent, plausible facts the agent can answer policy
# questions from.
_HR_CONTEXT = """
WSO2 People Operations reference facts (for answering policy questions):
- Annual leave: 20 days per year, accrued monthly, carries over up to 5
  unused days into the next year
- Benefits: private health insurance, WFH stipend, annual learning budget
- Onboarding: every new hire needs a laptop provisioned, a desk assigned,
  and enrollment in standard benefits
"""


class ResponseFormat(BaseModel):
    """Respond to the user in this format."""

    status: Literal['input_required', 'completed', 'error'] = 'input_required'
    message: str


class PeopleOperationsAgent:
    SYSTEM_INSTRUCTION = (
        'You are the WSO2 People Operations (HR) agent. Answer policy '
        'questions directly from the reference facts below. When asked to '
        'onboard a new hire, call provision_laptop, assign_desk, and '
        'enroll_benefits, in that order, for the named employee.\n'
        + _HR_CONTEXT
    )

    FORMAT_INSTRUCTION = (
        'Set response status to input_required if the user needs to provide more '
        'information to complete the request (e.g. missing the employee name for '
        'onboarding). Set response status to error if there is an error while '
        'processing the request. Set response status to completed once the '
        'question is answered or the onboarding steps are done. The message '
        'field is the ONLY thing the user will ever see — put the real answer '
        'or confirmation in it in full.'
    )

    def __init__(self) -> None:
        self.model = ChatAnthropic(model='claude-sonnet-4-5')
        self.tools = [provision_laptop, assign_desk, enroll_benefits]
        self.graph = create_react_agent(
            self.model,
            tools=self.tools,
            checkpointer=memory,
            prompt=self.SYSTEM_INSTRUCTION,
            response_format=(self.FORMAT_INSTRUCTION, ResponseFormat),
        )

    async def stream(self, query: str, context_id: str) -> AsyncIterable[dict[str, Any]]:
        inputs = {'messages': [('user', query)]}
        config = {'configurable': {'thread_id': context_id}}

        async for item in self.graph.astream(inputs, config, stream_mode='values'):
            message = item['messages'][-1]
            if (
                isinstance(message, AIMessage)
                and message.tool_calls
                and len(message.tool_calls) > 0
            ):
                tool_name = message.tool_calls[0]['name']
                yield {
                    'is_task_complete': False,
                    'require_user_input': False,
                    'content': f'Running onboarding step: {tool_name}...',
                }
            elif isinstance(message, ToolMessage):
                yield {
                    'is_task_complete': False,
                    'require_user_input': False,
                    'content': 'Step complete.',
                }

        yield self.get_agent_response(config)

    def get_agent_response(self, config: dict) -> dict[str, Any]:
        current_state = self.graph.get_state(config)
        structured_response = current_state.values.get('structured_response')
        if structured_response and isinstance(structured_response, ResponseFormat):
            if structured_response.status in ('input_required', 'error'):
                return {
                    'is_task_complete': False,
                    'require_user_input': True,
                    'content': structured_response.message,
                }
            if structured_response.status == 'completed':
                return {
                    'is_task_complete': True,
                    'require_user_input': False,
                    'content': structured_response.message,
                }

        return {
            'is_task_complete': False,
            'require_user_input': True,
            'content': 'Unable to process the request at the moment. Please try again.',
        }

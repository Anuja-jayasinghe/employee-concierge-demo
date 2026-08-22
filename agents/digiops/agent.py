from typing import Literal

from google.adk.agents import LlmAgent
from google.adk.models.anthropic_llm import AnthropicLlm
from pydantic import BaseModel, Field

from tickets import create_ticket, get_ticket

# Fictional-but-WSO2-styled IT context — no real internal policy or figures,
# consistent, plausible facts the agent can answer FAQ questions from.
_IT_CONTEXT = """
WSO2 IT reference facts (for answering FAQs):
- VPN client: GlobalProtect, connect to vpn.wso2.internal.example
- Password policy: minimum 12 characters, rotated every 90 days, reset via
  the self-service portal at idp.wso2.internal.example/reset
- Standard hardware catalog: laptop, monitor, docking station, headset —
  requests over the standard catalog need a manager approval step
"""


class AgentResponse(BaseModel):
    """Structured reply the LLM must produce.

    Attributes:
        message: The reply text for the user.
        status: completed | input-required | failed.
    """

    message: str = Field(description='Reply text for the user')
    status: Literal['completed', 'input-required', 'failed'] = Field(
        description='Status of the agent response'
    )


root_agent = LlmAgent(
    name='digiops_agent',
    model=AnthropicLlm(model='claude-opus-4-8'),
    description='WSO2 IT Helpdesk agent — FAQs and hardware ticket handling.',
    instruction=(
        'You are the WSO2 IT Helpdesk (DigiOps) agent. Answer FAQ-style '
        'questions directly from the reference facts below. For a hardware '
        'request, call create_ticket with a short item description. For a '
        'status check on an existing ticket, call get_ticket.\n'
        + _IT_CONTEXT
        + '\nAlways respond with ONLY a JSON object matching this exact '
        'shape, no other text: '
        '{"message": "<your reply text>", "status": "completed" | "input-required" | "failed"}. '
        'Use "completed" once the request has been fully answered or the '
        'ticket action performed, "input-required" when you need more '
        'information from the user, and "failed" only if a tool call errored.'
    ),
    tools=[create_ticket, get_ticket],
    output_schema=AgentResponse,
)

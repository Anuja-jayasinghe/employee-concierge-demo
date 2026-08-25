from typing import Literal

from google.adk.agents import LlmAgent
from google.adk.models.anthropic_llm import AnthropicLlm
from pydantic import BaseModel, Field

from data import SPOTS, find_mentioned_spot


def check_spot(spot_id: str) -> str:
    """Checks whether a specific WSO2 Colombo HQ parking spot is free, and
    who holds it if it's taken.

    Args:
        spot_id: The spot's id, e.g. "A01".

    Returns:
        A short real status for that spot, or a note that the id is unknown.
    """
    spot = find_mentioned_spot(spot_id)
    if spot is None:
        return f'"{spot_id}" is not a known spot id.'
    if spot.free:
        return f'Spot {spot.spot_id} ({spot.level}) is free.'
    holder = f', reserved by {spot.reserved_by}' if spot.reserved_by else ''
    return f'Spot {spot.spot_id} ({spot.level}) is taken{holder}.'


def list_free_spots() -> str:
    """Lists every currently free WSO2 Colombo HQ parking spot.

    Returns:
        A comma-separated list of free spot ids and their level, or a note
        that none are free.
    """
    free = [f'{s.spot_id} ({s.level})' for s in SPOTS.values() if s.free]
    return ', '.join(free) if free else 'No spots are currently free.'


class AgentResponse(BaseModel):
    """Structured reply the LLM must produce.

    Attributes:
        message: The reply text for the user.
        status: completed | input-required | failed.
        reserve_spot_id: Set only when the user clearly wants to reserve
            this exact spot and has given their name; left null for
            availability questions or when more information is needed
            before a reservation can proceed.
        employee_name: The requester's real name for a reservation. Only
            meaningful alongside reserve_spot_id.
    """

    message: str = Field(description='Reply text for the user')
    status: Literal['completed', 'input-required', 'failed'] = Field(
        description='Status of the agent response'
    )
    reserve_spot_id: str | None = Field(
        default=None,
        description=(
            'Set only when the user clearly wants to reserve this exact '
            'known spot id AND has given their name. Leave null for '
            'availability questions, or when a reservation was requested '
            'but no single clear spot id or no name was given -- ask a '
            'clarifying question instead and leave this null.'
        ),
    )
    employee_name: str | None = Field(
        default=None,
        description=(
            "The requester's real name, only set alongside reserve_spot_id "
            'when both the spot id and the name are known.'
        ),
    )


root_agent = LlmAgent(
    name='parking_agent',
    model=AnthropicLlm(model='claude-opus-4-8'),
    description='WSO2 Colombo HQ Parking Manager agent — availability lookups and reservations.',
    instruction=(
        'You are the WSO2 Colombo HQ Parking Manager agent. For an '
        'availability question (including general ones like "is anything '
        'free?"), call list_free_spots or check_spot as needed and answer '
        'from the real result -- never guess at spot state yourself.\n\n'
        'For a reservation request, your job is to decide which single spot '
        'id the user wants AND get their real name -- do NOT call check_spot '
        'or list_free_spots for a reservation request, and do not decide or '
        'comment on whether that spot is actually free; a separate real '
        'system checks that and will report back if it is taken. Every real '
        'reservation is tied to a real employee, so if they have not told '
        'you their name yet, ask for it before reserving anything -- do not '
        'reserve a spot without a name, and do not invent or assume one. If '
        'they name one real spot id clearly AND have given their name, set '
        'reserve_spot_id and employee_name and status to "completed" '
        'regardless of whether you think the spot might already be taken. '
        'If they ask to reserve a spot but do not give a clear single spot '
        'id (e.g. "reserve me a spot on level 2"), or have not given their '
        'name yet, ask a real clarifying question for whichever is missing '
        'and leave reserve_spot_id/employee_name null -- do not guess or '
        'pick one for them.\n\n'
        'Use "completed" once the request has been fully answered, '
        '"input-required" when you need more information from the user, '
        'and "failed" only if a tool call errored.'
    ),
    tools=[check_spot, list_free_spots],
    output_schema=AgentResponse,
)

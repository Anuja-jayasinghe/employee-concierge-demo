"""Mock hardware-ticket store for the DigiOps agent.

Tool functions called by the real LLM (see agent.py) — the actions are
genuine (they mutate real in-memory state the agent lifecycle depends on),
the persistence layer is just in-memory for the demo.
"""

import uuid

_TICKETS: dict[str, dict] = {}


def create_ticket(item: str) -> dict:
    """Opens a hardware provisioning ticket.

    Args:
        item: A short description of the requested hardware, e.g. "laptop charger".
    """
    ticket_id = str(uuid.uuid4())[:8]
    _TICKETS[ticket_id] = {'item': item, 'status': 'open'}
    return {'ticket_id': ticket_id, 'item': item, 'status': 'open'}


def get_ticket(ticket_id: str) -> dict:
    """Looks up the status of an existing hardware ticket.

    Args:
        ticket_id: The ticket identifier returned by create_ticket.
    """
    ticket = _TICKETS.get(ticket_id)
    if ticket is None:
        return {'error': f'no ticket found with id {ticket_id}'}
    return {'ticket_id': ticket_id, **ticket}

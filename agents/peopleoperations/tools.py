"""Real onboarding tool functions the LangGraph agent calls — each call is a
genuine state mutation (an in-memory onboarding checklist), not canned text.
Calling them in sequence during onboarding is what produces the LLM's own
progress narration in the streaming flow (see agent.py's stream()).
"""

from langchain_core.tools import tool

_CHECKLISTS: dict[str, dict[str, bool]] = {}


@tool
def provision_laptop(employee_name: str) -> dict:
    """Provisions a laptop for a new hire.

    Args:
        employee_name: The new hire's name.
    """
    checklist = _CHECKLISTS.setdefault(employee_name, {})
    checklist['laptop'] = True
    return {'step': 'laptop', 'done': True}


@tool
def assign_desk(employee_name: str) -> dict:
    """Assigns a desk to a new hire.

    Args:
        employee_name: The new hire's name.
    """
    checklist = _CHECKLISTS.setdefault(employee_name, {})
    checklist['desk'] = True
    return {'step': 'desk', 'done': True}


@tool
def enroll_benefits(employee_name: str) -> dict:
    """Enrolls a new hire in standard benefits.

    Args:
        employee_name: The new hire's name.
    """
    checklist = _CHECKLISTS.setdefault(employee_name, {})
    checklist['benefits'] = True
    return {'step': 'benefits', 'done': True}

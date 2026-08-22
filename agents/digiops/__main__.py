import uvicorn

from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.routes import create_agent_card_routes, create_jsonrpc_routes
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import (
    AgentCapabilities,
    AgentCard,
    AgentInterface,
    AgentSkill,
)
from starlette.applications import Starlette

from agent_executor import DigiOpsAgentExecutor

HOST = '127.0.0.1'
PORT = 8001

if __name__ == '__main__':
    skills = [
        AgentSkill(
            id='faq-answer',
            name='Answer IT FAQs',
            description='Answers common IT questions — VPN access, password resets, standard hardware.',
            tags=['it', 'faq'],
            examples=['how do I connect to the VPN?'],
        ),
        AgentSkill(
            id='hardware-request',
            name='Request hardware',
            description='Opens and tracks a hardware provisioning ticket.',
            tags=['it', 'ticket'],
            examples=['I need a new laptop charger'],
        ),
        AgentSkill(
            id='incident-investigation',
            name='Investigate an incident',
            description='Investigates a reported IT incident with live status updates.',
            tags=['it', 'incident'],
            examples=['my laptop cannot reach the internal network'],
        ),
    ]

    agent_card = AgentCard(
        name='DigiOps Agent',
        description='WSO2 IT Helpdesk — FAQs, hardware requests, and live incident investigation.',
        version='0.1.0',
        default_input_modes=['text/plain'],
        default_output_modes=['text/plain'],
        capabilities=AgentCapabilities(
            streaming=True,
            push_notifications=False,
            extended_agent_card=False,
        ),
        supported_interfaces=[
            AgentInterface(
                protocol_binding='JSONRPC',
                url=f'http://{HOST}:{PORT}',
                protocol_version='1.0',
            )
        ],
        skills=skills,
    )

    request_handler = DefaultRequestHandler(
        agent_executor=DigiOpsAgentExecutor(),
        task_store=InMemoryTaskStore(),
        agent_card=agent_card,
    )

    routes = []
    routes.extend(create_agent_card_routes(agent_card))
    routes.extend(create_jsonrpc_routes(request_handler, '/'))

    app = Starlette(routes=routes)
    uvicorn.run(app, host=HOST, port=PORT)

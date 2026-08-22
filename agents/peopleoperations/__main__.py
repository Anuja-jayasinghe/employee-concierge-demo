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

from agent_executor import PeopleOperationsAgentExecutor

HOST = '127.0.0.1'
PORT = 8002

if __name__ == '__main__':
    skills = [
        AgentSkill(
            id='policy-qa',
            name='Answer HR policy questions',
            description='Answers common HR policy questions — leave, benefits.',
            tags=['hr', 'policy'],
            examples=['how many annual leave days do I have?'],
        ),
        AgentSkill(
            id='onboarding',
            name='Run onboarding checklist',
            description='Runs a new-hire onboarding checklist with live progress updates.',
            tags=['hr', 'onboarding'],
            examples=['start my onboarding checklist'],
        ),
    ]

    agent_card = AgentCard(
        name='PeopleOperations Agent',
        description='WSO2 People Operations — policy Q&A and onboarding.',
        version='0.1.0',
        default_input_modes=['text/plain'],
        default_output_modes=['text/plain'],
        capabilities=AgentCapabilities(
            streaming=True,
            push_notifications=False,
            extended_agent_card=True,
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
        agent_executor=PeopleOperationsAgentExecutor(),
        task_store=InMemoryTaskStore(),
        agent_card=agent_card,
    )

    routes = []
    routes.extend(create_agent_card_routes(agent_card))
    routes.extend(create_jsonrpc_routes(request_handler, '/'))

    app = Starlette(routes=routes)
    uvicorn.run(app, host=HOST, port=PORT)

import uvicorn

from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.routes import create_agent_card_routes, create_rest_routes
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import (
    AgentCapabilities,
    AgentCard,
    AgentInterface,
    AgentSkill,
)
from starlette.applications import Starlette

from agent_executor import ParkingAgentExecutor

HOST = '127.0.0.1'
PORT = 8000

if __name__ == '__main__':
    skills = [
        AgentSkill(
            id='check-availability',
            name='Check parking availability',
            description='Look up whether a given office parking spot is currently free.',
            tags=['parking'],
            examples=['is spot A12 free today?'],
        ),
        AgentSkill(
            id='reserve-spot',
            name='Reserve a parking spot',
            description='Reserve a specific office parking spot.',
            tags=['parking'],
            examples=['reserve spot A12 for tomorrow'],
        ),
        AgentSkill(
            id='cancel-reservation',
            name='Cancel a reservation',
            description='Cancel an in-progress parking reservation.',
            tags=['parking'],
            examples=['cancel my reservation for spot A12'],
        ),
    ]

    agent_card = AgentCard(
        name='Parking Manager Agent',
        description='Look up parking availability and manage reservations for WSO2 office parking.',
        version='0.1.0',
        default_input_modes=['text/plain'],
        default_output_modes=['text/plain'],
        capabilities=AgentCapabilities(
            streaming=False,
            push_notifications=True,
            extended_agent_card=False,
        ),
        supported_interfaces=[
            AgentInterface(
                protocol_binding='HTTP+JSON',
                url=f'http://{HOST}:{PORT}',
                protocol_version='1.0',
            )
        ],
        skills=skills,
    )

    request_handler = DefaultRequestHandler(
        agent_executor=ParkingAgentExecutor(),
        task_store=InMemoryTaskStore(),
        agent_card=agent_card,
    )

    routes = []
    routes.extend(create_agent_card_routes(agent_card))
    routes.extend(create_rest_routes(request_handler))

    app = Starlette(routes=routes)
    uvicorn.run(app, host=HOST, port=PORT)

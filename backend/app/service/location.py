from fastapi.params import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.event import EventBase
from app.schemas.message import LocationBase
from app.service.event.event_sender import EventSenderProtocol
from app.service.event.event_strategy import SenderSelectionContext
from app.service.event.events import EventStrategyFactory, \
    get_event_strategy_factory


class LocationService:

    def __init__(self,
        event_strategy_factory: EventStrategyFactory):
        self.event_strategy_factory = event_strategy_factory

    async def send_location_stream(self,
        db: AsyncSession,
        user_id: int,
        stream_id: int,
        location: LocationBase,
    ) -> None:
        event = EventBase(
            type='location',
            data={
                'lat': location.lat,
                'lng': location.lng,
            }
        )
        context = SenderSelectionContext(
            user_id=user_id,
            stream_id=stream_id,
            event=event
        )
        strategy = self.event_strategy_factory.get_strategy(context.event.type)
        event_sender: EventSenderProtocol = await strategy.get_sender(db, context)
        await event_sender.send_event(context.user_id, context.event)



def get_location_service(event_strategy_factory: EventStrategyFactory =
Depends(get_event_strategy_factory))-> LocationService:
    return LocationService(event_strategy_factory)
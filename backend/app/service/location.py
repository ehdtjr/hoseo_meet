from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.stream import SubscriptionCRUDProtocol, get_subscription_crud
from app.schemas.event import EventBase
from app.schemas.message import LocationBase
from app.service.event.events import EventDispatcher, get_event_dispatcher


class LocationService:

    def __init__(self, event_dispatch: EventDispatcher,
                 subscription_crud: SubscriptionCRUDProtocol,
                 ):
        self.event_dispatch = event_dispatch
        self.subscription_crud = subscription_crud

    async def send_location_stream(self, db: AsyncSession,
                                   stream_id: int,
                                   user_id: int,
                                   location: LocationBase) -> None:
        event = EventBase(
            type='location',
            data={
                'user_id': user_id,
                'lat': location.lat,
                'lng': location.lng,
            }
        )
        subscribers = await self.subscription_crud.get_subscribers(db,
                                                                   stream_id)

        await self.event_dispatch.dispatch(db, user_ids=subscribers,
                                           stream_id=stream_id,
                                           event_data=event)


def get_location_service(
        event_dispatch: EventDispatcher = Depends(get_event_dispatcher),
        subscription_crud: SubscriptionCRUDProtocol = Depends(
            get_subscription_crud)
):
    return LocationService(
        event_dispatch=event_dispatch,
        subscription_crud=subscription_crud,
    )

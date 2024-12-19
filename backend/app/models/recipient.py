from sqlalchemy import Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class Recipient(Base):
    """
    Recipient
    type: 1=user, 2=stream
    type_id: user_id or stream_id
    """
    __tablename__ = "recipient"

    id: Mapped[int] = mapped_column(Integer, primary_key=True,
                                    autoincrement=True)
    type: Mapped[int] = mapped_column(Integer)
    type_id: Mapped[int] = mapped_column(Integer)

    streams: Mapped["Stream"] = relationship("Stream",
                                             back_populates="recipient")
    subscriptions: Mapped["Subscription"] = relationship("Subscription",
                                                         back_populates="recipient")
    __table_args__ = (UniqueConstraint("type",
                                       "type_id", name="uix_type_type_id"),)

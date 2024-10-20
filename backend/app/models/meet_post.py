import uuid

from sqlalchemy import (
    Column,
    ForeignKey,
    String,
    Integer,
    DateTime,
    func,
    CheckConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.core.db import Base


class MeetPost(Base):
    __tablename__ = "meet_post"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        unique=True,
        nullable=False,
    )
    author_id = Column(UUID(as_uuid=True), ForeignKey("user.id"), nullable=False)
    title = Column(String(20), nullable=False)
    type = Column(String(20), nullable=False)
    content = Column(String(200), nullable=False)
    page_view = Column(Integer, default=0)
    max_people = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    author = relationship("User", back_populates="meet_posts")

    __table_args__ = (
        CheckConstraint(
            "max_people > 0 AND max_people <= 100", name="check_max_people"
        ),
    )

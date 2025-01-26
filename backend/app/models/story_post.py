from sqlalchemy import Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class StoryPost(Base):
    __tablename__ = 'story_post'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
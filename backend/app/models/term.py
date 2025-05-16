from datetime import datetime
from typing import List

from sqlalchemy import String, DateTime, func, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class UserTermAgreement(Base):
    __tablename__ = "user_term_agreement"

    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), primary_key=True)
    term_id: Mapped[int] = mapped_column(ForeignKey("terms.id"), primary_key=True)
    agreed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="term_agreements")
    term: Mapped["Term"] = relationship("Term", back_populates="user_terms")


class Term(Base):
    __tablename__ = "terms"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    version: Mapped[str] = mapped_column(String(10), nullable=False)
    content: Mapped[str] = mapped_column(String, nullable=False)
    is_required: Mapped[bool] = mapped_column(nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user_terms: Mapped[List["UserTermAgreement"]] = relationship("UserTermAgreement", back_populates="term")

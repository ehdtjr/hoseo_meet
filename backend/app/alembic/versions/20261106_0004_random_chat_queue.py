"""Add the durable random-chat matching queue."""

from alembic import op
import sqlalchemy as sa


revision = "20261106_0004"
down_revision = "20261106_0003"
branch_labels = None
depends_on = None


def extend_schema(metadata: sa.MetaData) -> None:
    """Extend a frozen earlier revision to this revision's schema."""
    queue = sa.Table(
        "random_chat_queue",
        metadata,
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("queued_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("stream_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["stream_id"], ["streams.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )
    sa.Index(
        "ix_random_chat_queue_fifo",
        queue.c.stream_id,
        queue.c.queued_at,
        queue.c.user_id,
    )
    sa.Index("ix_random_chat_queue_expiry", queue.c.expires_at)


def upgrade() -> None:
    # These stubs resolve foreign keys; only the queue table is created.
    metadata = sa.MetaData()
    sa.Table("user", metadata, sa.Column("id", sa.Integer(), primary_key=True))
    sa.Table("streams", metadata, sa.Column("id", sa.Integer(), primary_key=True))
    extend_schema(metadata)
    metadata.tables["random_chat_queue"].create(bind=op.get_bind(), checkfirst=False)


def downgrade() -> None:
    """Destructively remove all queued and recorded random-chat matches."""
    op.drop_table("random_chat_queue")

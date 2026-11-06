"""Add idempotent message keys and the durable delivery outbox."""

from alembic import op
import sqlalchemy as sa


revision = "20261106_0003"
down_revision = "20261106_0002"
branch_labels = None
depends_on = None


def extend_schema(metadata: sa.MetaData) -> None:
    """Extend a frozen earlier revision to this revision's schema."""
    message = metadata.tables["message"]
    message.append_column(
        sa.Column("client_message_id", sa.String(length=128), nullable=True)
    )
    sa.Index(
        "message_sender_client_id",
        message.c.sender_id,
        message.c.client_message_id,
        unique=True,
    )

    outbox = sa.Table(
        "message_outbox",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("message_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("stream_id", sa.Integer(), nullable=False),
        sa.Column("payload", sa.Text(), nullable=False),
        sa.Column(
            "channel",
            sa.String(length=16),
            server_default="route",
            nullable=False,
        ),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "available_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("outcome", sa.String(length=32), nullable=True),
        sa.Column("last_error", sa.String(length=64), nullable=True),
        sa.ForeignKeyConstraint(["message_id"], ["message.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Index(
        "message_outbox_recipient",
        outbox.c.message_id,
        outbox.c.user_id,
        unique=True,
    )
    sa.Index(
        "message_outbox_channel_pending",
        outbox.c.channel,
        outbox.c.available_at,
        outbox.c.id,
        postgresql_where=outbox.c.completed_at.is_(None),
    )


def upgrade() -> None:
    op.add_column(
        "message",
        sa.Column("client_message_id", sa.String(length=128), nullable=True),
    )
    op.create_index(
        "message_sender_client_id",
        "message",
        ["sender_id", "client_message_id"],
        unique=True,
    )

    # These stubs resolve the outbox foreign keys; only the outbox table is
    # created from this metadata.
    metadata = sa.MetaData()
    sa.Table(
        "message",
        metadata,
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sender_id", sa.Integer(), nullable=False),
    )
    sa.Table("user", metadata, sa.Column("id", sa.Integer(), primary_key=True))
    extend_schema(metadata)
    metadata.tables["message_outbox"].create(bind=op.get_bind(), checkfirst=False)


def downgrade() -> None:
    """Destructively remove pending deliveries and stored idempotency keys."""
    op.drop_table("message_outbox")
    op.drop_index("message_sender_client_id", table_name="message")
    op.drop_column("message", "client_message_id")

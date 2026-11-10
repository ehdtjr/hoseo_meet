"""Track resumable AI tagging independently of user tags."""

from alembic import op
import sqlalchemy as sa

revision = "20261110_0006"
down_revision = "20261108_0005"
branch_labels = None
depends_on = None


def add_table(metadata: sa.MetaData) -> sa.Table:
    return sa.Table(
        "user_tagging_checkpoint",
        metadata,
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("analysis_version", sa.String(50), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("last_message_id", sa.Integer(), nullable=False),
        sa.Column("target_message_id", sa.Integer(), nullable=False),
        sa.Column("last_error", sa.String(100), nullable=True),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
        sa.CheckConstraint(
            "status IN ('pending', 'running', 'failed', 'completed')",
            name="ck_user_tagging_checkpoint_status",
        ),
    )


def add_message_index(metadata: sa.MetaData) -> sa.Index:
    messages = metadata.tables["chat_bot_message"]
    return sa.Index(
        "ix_chat_bot_message_user_id_id", messages.c.user_id, messages.c.id
    )


def upgrade() -> None:
    # Include the FK target for SQLAlchemy's DDL dependency resolution only.
    metadata = sa.MetaData()
    sa.Table("user", metadata, sa.Column("id", sa.Integer(), primary_key=True))
    sa.Table(
        "chat_bot_message", metadata,
        sa.Column("user_id", sa.Integer()), sa.Column("id", sa.Integer()),
    )
    add_table(metadata).create(bind=op.get_bind(), checkfirst=False)
    add_message_index(metadata).create(bind=op.get_bind(), checkfirst=False)


def downgrade() -> None:
    raise RuntimeError(
        "Restore a database backup to roll back AI tagging checkpoints"
    )

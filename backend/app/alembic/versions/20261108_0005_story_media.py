"""Record story upload ownership without inferring legacy URL ownership."""

from alembic import op
import sqlalchemy as sa

revision = "20261108_0005"
down_revision = "20261106_0004"
branch_labels = None
depends_on = None


def add_table(metadata: sa.MetaData) -> sa.Table:
    return sa.Table(
        "story_media",
        metadata,
        sa.Column("key", sa.String(255), nullable=False),
        sa.Column("uploader_id", sa.Integer(), nullable=False),
        sa.Column("storage_backend", sa.String(20), nullable=False),
        sa.Column("upload_url", sa.Text(), nullable=False),
        sa.Column("claimed", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("key"),
        sa.UniqueConstraint("upload_url"),
    )


def upgrade() -> None:
    add_table(sa.MetaData()).create(bind=op.get_bind(), checkfirst=False)


def downgrade() -> None:
    # Provenance is needed to avoid deleting another owner's file on recovery.
    raise RuntimeError(
        "Restore a database/media backup to roll back story media ownership"
    )

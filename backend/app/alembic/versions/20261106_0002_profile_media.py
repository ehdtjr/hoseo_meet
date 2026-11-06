"""Track ownership of uploaded profile images."""

from alembic import op
import sqlalchemy as sa

revision = "20261106_0002"
down_revision = "20261106_0001"
branch_labels = None
depends_on = None


def add_table(metadata: sa.MetaData) -> sa.Table:
    """Frozen addition, also used to recognize unversioned create_all databases."""
    return sa.Table(
        "profile_media",
        metadata,
        sa.Column("uploader_id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(length=255), nullable=False),
        sa.Column("storage_backend", sa.String(length=20), nullable=False),
        sa.ForeignKeyConstraint(["uploader_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("uploader_id"),
        sa.UniqueConstraint("key"),
    )


def upgrade() -> None:
    # Define the referenced table for SQLAlchemy's foreign-key resolution only.
    metadata = sa.MetaData()
    sa.Table("user", metadata, sa.Column("id", sa.Integer(), primary_key=True))
    add_table(metadata).create(bind=op.get_bind(), checkfirst=False)


def downgrade() -> None:
    op.drop_table("profile_media")

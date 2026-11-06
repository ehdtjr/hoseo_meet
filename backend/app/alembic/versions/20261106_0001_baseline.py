"""Frozen baseline before profile-media ownership tracking.

Do not import application models here: this schema must survive future model edits.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
import geoalchemy2

revision = "20261106_0001"
down_revision = None
branch_labels = None
depends_on = None


def schema() -> sa.MetaData:
    """Return immutable baseline definitions, also used to validate legacy adoption."""
    metadata = sa.MetaData()
    sa.Table(
        "recipient",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("type", sa.Integer(), nullable=False),
        sa.Column("type_id", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("type", "type_id", name="uix_type_type_id"),
    )
    sa.Table(
        "room_post",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(length=50), nullable=False),
        sa.Column("address", sa.String(length=50), nullable=False),
        sa.Column("contact", sa.String(length=50), nullable=True),
        sa.Column("price", sa.String(length=50), nullable=True),
        sa.Column("fee", sa.String(length=50), nullable=True),
        sa.Column("options", sa.String(length=200), nullable=True),
        sa.Column("gas_type", sa.String(length=50), nullable=True),
        sa.Column("comment", sa.String(length=200), nullable=True),
        sa.Column("place", sa.String(length=50), nullable=False),
        sa.Column(
            "location",
            geoalchemy2.types.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
                nullable=False,
            ),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "tag",
        metadata,
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=50), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    sa.Table(
        "terms",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("version", sa.String(length=10), nullable=False),
        sa.Column("content", sa.String(), nullable=False),
        sa.Column("is_required", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "user",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("gender", sa.String(length=20), nullable=False),
        sa.Column("profile", sa.String(length=1024), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("hashed_password", sa.String(length=1024), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("is_superuser", sa.Boolean(), nullable=False),
        sa.Column("is_verified", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    sa.Index("ix_user_email", metadata.tables["user"].c["email"], unique=True)
    sa.Table(
        "chat_bot_message",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("role", sa.Text(), nullable=False),
        sa.Column("content", sa.String(), nullable=False),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "message",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=False),
        sa.Column(
            "type",
            sa.Enum("NORMAL", "RESOLVE_TOPIC_NOTIFICATION", name="messagetype"),
            nullable=False,
        ),
        sa.Column("recipient_id", sa.Integer(), nullable=False),
        sa.Column("content", sa.String(), nullable=False),
        sa.Column("rendered_content", sa.String(), nullable=True),
        sa.Column("date_sent", sa.DateTime(timezone=True), nullable=False),
        sa.Column("has_attachment", sa.Boolean(), nullable=False),
        sa.Column("has_image", sa.Boolean(), nullable=False),
        sa.Column("has_link", sa.Boolean(), nullable=False),
        sa.Column(
            "search_tsvector",
            postgresql.TSVECTOR(),
            sa.Computed("to_tsvector('simple', content)", persisted=True),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(["recipient_id"], ["recipient.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["sender_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Index(
        "ix_message_has_attachment",
        metadata.tables["message"].c["has_attachment"],
        unique=False,
    )
    sa.Index(
        "ix_message_has_image", metadata.tables["message"].c["has_image"], unique=False
    )
    sa.Index(
        "ix_message_has_link", metadata.tables["message"].c["has_link"], unique=False
    )
    sa.Index(
        "ix_message_search_tsvector",
        metadata.tables["message"].c["search_tsvector"],
        unique=False,
    )
    sa.Index(
        "message_recipient",
        metadata.tables["message"].c["recipient_id"],
        metadata.tables["message"].c["id"],
        unique=False,
    )
    sa.Index(
        "message_search_tsvector_idx",
        metadata.tables["message"].c["search_tsvector"],
        unique=False,
        postgresql_using="gin",
    )
    sa.Index(
        "message_sender_recipient",
        metadata.tables["message"].c["sender_id"],
        metadata.tables["message"].c["recipient_id"],
        unique=False,
    )
    sa.Table(
        "oauth_account",
        metadata,
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("oauth_name", sa.String(length=100), nullable=False),
        sa.Column("access_token", sa.String(length=1024), nullable=False),
        sa.Column("expires_at", sa.Integer(), nullable=True),
        sa.Column("refresh_token", sa.String(length=1024), nullable=True),
        sa.Column("account_id", sa.String(length=320), nullable=False),
        sa.Column("account_email", sa.String(length=320), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="cascade"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Index(
        "ix_oauth_account_account_id",
        metadata.tables["oauth_account"].c["account_id"],
        unique=False,
    )
    sa.Index(
        "ix_oauth_account_oauth_name",
        metadata.tables["oauth_account"].c["oauth_name"],
        unique=False,
    )
    sa.Table(
        "restaurant_post",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("editor_id", sa.Integer(), nullable=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("contact", sa.Text(), nullable=True),
        sa.Column("business_hours", sa.Text(), nullable=True),
        sa.Column(
            "location",
            geoalchemy2.types.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
                nullable=False,
            ),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["editor_id"], ["user.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "room_post_heart",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["room_id"], ["room_post.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "room_id", name="uq_user_room_heart"),
    )
    sa.Table(
        "room_post_image",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("image", sa.String(length=200), nullable=False),
        sa.ForeignKeyConstraint(["room_id"], ["room_post.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "room_review",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("author_id", sa.Integer(), nullable=False),
        sa.Column("content", sa.String(length=200), nullable=False),
        sa.Column("rating", sa.NUMERIC(precision=3, scale=1), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["author_id"], ["user.id"]),
        sa.ForeignKeyConstraint(["room_id"], ["room_post.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "streams",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(length=20), nullable=False),
        sa.Column("type", sa.String(length=20), nullable=False),
        sa.Column(
            "date_created",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("creator_id", sa.Integer(), nullable=False),
        sa.Column("recipient_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["creator_id"], ["user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["recipient_id"], ["recipient.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Index("ix_streams_name", metadata.tables["streams"].c["name"], unique=False)
    sa.Index("ix_streams_type", metadata.tables["streams"].c["type"], unique=False)
    sa.Table(
        "subscriptions",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("recipient_id", sa.Integer(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("is_user_active", sa.Boolean(), nullable=False),
        sa.Column("is_muted", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["recipient_id"], ["recipient.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "recipient_id"),
    )
    sa.Index(
        "subscription_recipient_id_user_id_idx",
        metadata.tables["subscriptions"].c["recipient_id"],
        metadata.tables["subscriptions"].c["user_id"],
        unique=False,
        postgresql_where=sa.text("active = true AND is_user_active = true"),
    )
    sa.Table(
        "user_fcm_token",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("fcm_token", sa.String(length=255), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "user_report",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("reporter_id", sa.Integer(), nullable=False),
        sa.Column("reported_user_id", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=500), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("is_resolved", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["reported_user_id"], ["user.id"]),
        sa.ForeignKeyConstraint(["reporter_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "user_tag",
        metadata,
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("tag_id", sa.Integer(), nullable=False),
        sa.Column("score", sa.Float(), nullable=False),
        sa.ForeignKeyConstraint(["tag_id"], ["tag.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "user_term_agreement",
        metadata,
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("term_id", sa.Integer(), nullable=False),
        sa.Column(
            "agreed_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["term_id"], ["terms.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("user_id", "term_id"),
    )
    sa.Table(
        "meet_post",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("author_id", sa.Integer(), nullable=False),
        sa.Column("stream_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=50), nullable=False),
        sa.Column("type", sa.String(length=50), nullable=False),
        sa.Column("content", sa.String(length=200), nullable=False),
        sa.Column("page_views", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("max_people", sa.Integer(), nullable=False),
        sa.CheckConstraint(
            "max_people >= 1 AND max_people <= 50", name="check_max_people"
        ),
        sa.ForeignKeyConstraint(["author_id"], ["user.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["stream_id"], ["streams.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "restaurant_heart",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "post_id", name="uq_user_post_heart"),
    )
    sa.Table(
        "restaurant_menu",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("editor_id", sa.Integer(), nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.Column("image", sa.String(length=200), nullable=True),
        sa.ForeignKeyConstraint(["editor_id"], ["user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "restaurant_menu_set_version",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("menus", postgresql.JSON(astext_type=sa.Text()), nullable=False),
        sa.Column("editor_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["editor_id"], ["user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "restaurant_post_image",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("image", sa.String(length=200), nullable=False),
        sa.Column("editor_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["editor_id"], ["user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "restaurant_post_image_set_version",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("image_urls", postgresql.JSON(astext_type=sa.Text()), nullable=False),
        sa.Column("editor_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["editor_id"], ["user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "restaurant_post_version",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("editor_id", sa.Integer(), nullable=True),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("contact", sa.Text(), nullable=True),
        sa.Column("business_hours", sa.Text(), nullable=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column(
            "location",
            geoalchemy2.types.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
                nullable=False,
            ),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["editor_id"], ["user.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "restaurant_review",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("author_id", sa.Integer(), nullable=False),
        sa.Column("content", sa.String(length=200), nullable=False),
        sa.Column("rating", sa.NUMERIC(precision=3, scale=1), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["author_id"], ["user.id"]),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "room_review_image",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("review_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("image", sa.String(length=200), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["review_id"], ["room_review.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["room_id"], ["room_post.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "story_post",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("author_id", sa.Integer(), nullable=False),
        sa.Column("stream_id", sa.Integer(), nullable=False),
        sa.Column("text_overlay", sa.JSON(), nullable=True),
        sa.Column("image_url", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["author_id"], ["user.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["stream_id"], ["streams.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Table(
        "user_message",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("message_id", sa.Integer(), nullable=False),
        sa.Column("is_read", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["message_id"], ["message.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    sa.Index(
        "idx_user_message_unread",
        metadata.tables["user_message"].c["message_id"],
        unique=False,
        postgresql_where=sa.text("is_read = false"),
    )
    sa.Index(
        "user_message_user_id_is_read_msgid_idx",
        metadata.tables["user_message"].c["user_id"],
        metadata.tables["user_message"].c["is_read"],
        metadata.tables["user_message"].c["message_id"],
        unique=False,
    )
    sa.Table(
        "restaurant_review_image",
        metadata,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("review_id", sa.Integer(), nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("image", sa.String(length=200), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["post_id"], ["restaurant_post.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["review_id"], ["restaurant_review.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    return metadata


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    schema().create_all(bind=op.get_bind(), checkfirst=False)


def downgrade() -> None:
    raise RuntimeError(
        "Baseline downgrade is disabled: restore a verified backup instead"
    )

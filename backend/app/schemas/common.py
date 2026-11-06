from typing import Literal

PublicStreamType = Literal["meet", "delivery", "taxi", "carpool", "story"]
PostType = Literal[PublicStreamType, "random"]

MeetPostType = Literal["meet", "delivery", "taxi", "carpool"]

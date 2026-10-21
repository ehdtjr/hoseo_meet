from datetime import datetime

import pytz


def convert_to_local_time(utc_time: datetime, timezone: str = "Asia/Seoul") -> datetime:
    local_tz = pytz.timezone(timezone)
    return utc_time.astimezone(local_tz)
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.models.user import User

async def generate_tokens(user: User) -> dict:
    """
    Generate access_token and refresh_token for the given user.
    """
    
    return {
        "access_token": create_access_token(user.id),
        "refresh_token": create_refresh_token(user.id),
    }

async def verify_token(token: str, token_type: str) -> str:
    """
    Verify the given token (access or refresh).
    """
    try:
        payload = decode_token(token)
        return payload.get("sub")
    except Exception as e:
        raise ValueError(f"Invalid {token_type} token: {str(e)}")

class PermissionDeniedException(Exception):
    def __init__(self, message: str = "권한이 없습니다."):
        self.message = message
        super().__init__(self.message)
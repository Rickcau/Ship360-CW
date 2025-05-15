import threading
import time
from typing import Tuple, Dict, Optional
from semantic_kernel.agents import ChatHistoryAgentThread

# Type alias for thread key
ThreadKey = Tuple[str, str]  # (userId, sessionId)

class ThreadStore:
    """Thread-safe in-memory store for ChatHistoryAgentThread objects."""

    def __init__(self, thread_ttl_seconds: int = 3600):
        self._store: Dict[ThreadKey, Tuple[ChatHistoryAgentThread, float]] = {}
        self._lock = threading.Lock()
        self._thread_ttl = thread_ttl_seconds

    def get_thread(self, user_id: str, session_id: str) -> ChatHistoryAgentThread:
        key = (user_id, session_id)
        with self._lock:
            if key in self._store:
                thread, _ = self._store[key]
                self._store[key] = (thread, time.time())
                return thread
            # Create new thread if not exists
            thread = ChatHistoryAgentThread(thread_id=session_id)
            self._store[key] = (thread, time.time())
            return thread

    def update_thread(self, user_id: str, session_id: str, thread: ChatHistoryAgentThread):
        key = (user_id, session_id)
        with self._lock:
            self._store[key] = (thread, time.time())

    def delete_thread(self, user_id: str, session_id: str):
        key = (user_id, session_id)
        with self._lock:
            if key in self._store:
                del self._store[key]

    def cleanup_threads(self):
        """Remove threads that have not been accessed within TTL."""
        now = time.time()
        with self._lock:
            keys_to_delete = [
                key for key, (_, last_access) in self._store.items()
                if now - last_access > self._thread_ttl
            ]
            for key in keys_to_delete:
                del self._store[key]

    def get_all_keys(self):
        with self._lock:
            return list(self._store.keys())

# Singleton instance for app-wide use
thread_store = ThreadStore()
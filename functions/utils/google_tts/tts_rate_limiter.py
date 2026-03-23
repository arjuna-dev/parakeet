"""
Global limiter for Google Cloud TTS (synthesize_speech) to stay under quota
(e.g. 500 requests/minute per project per base model).

Uses: (1) max concurrent in-flight RPCs, (2) minimum spacing between call starts
so aggregate throughput stays below max_per_minute.
"""
import os
import threading
import time

# Tunable via env (optional)
_MAX_PER_MINUTE = int(os.environ.get("TTS_MAX_PER_MINUTE", "450"))
_MAX_CONCURRENT = int(os.environ.get("TTS_MAX_CONCURRENT", "12"))


class _GlobalTtsLimiter:
    """Context manager: acquire before synthesize_speech, release after."""

    def __init__(self, max_per_minute: int, max_concurrent: int):
        self._min_interval = 60.0 / float(max(1, max_per_minute))
        self._sem = threading.BoundedSemaphore(max(1, max_concurrent))
        self._interval_lock = threading.Lock()
        self._next_allowed_monotonic = 0.0

    def __enter__(self):
        self._sem.acquire()
        with self._interval_lock:
            now = time.monotonic()
            if now < self._next_allowed_monotonic:
                time.sleep(self._next_allowed_monotonic - now)
                now = time.monotonic()
            self._next_allowed_monotonic = now + self._min_interval
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._sem.release()
        return False


_GLOBAL = _GlobalTtsLimiter(_MAX_PER_MINUTE, _MAX_CONCURRENT)


def tts_synthesis_slot():
    """Context manager to wrap each synthesize_speech call."""
    if os.environ.get("DISABLE_TTS_RATE_LIMIT", "").lower() in ("1", "true", "yes"):
        return _NoOpContext()
    return _GLOBAL


class _NoOpContext:
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        return False

from __future__ import annotations

import struct


def _iter_boxes(data: bytes, start: int, end: int):
    offset = start
    while offset + 8 <= end:
        size = struct.unpack(">I", data[offset : offset + 4])[0]
        box_type = data[offset + 4 : offset + 8]
        header = 8
        if size == 1:
            if offset + 16 > end:
                break
            size = struct.unpack(">Q", data[offset + 8 : offset + 16])[0]
            header = 16
        elif size == 0:
            size = end - offset
        if size < header or offset + size > end:
            break
        yield box_type, offset + header, offset + size
        offset += size


def _find_mvhd(data: bytes, start: int, end: int) -> tuple[int, int] | None:
    for box_type, body_start, body_end in _iter_boxes(data, start, end):
        if box_type == b"mvhd":
            version = data[body_start]
            if version == 1:
                timescale = struct.unpack(">I", data[body_start + 20 : body_start + 24])[0]
                duration = struct.unpack(">Q", data[body_start + 24 : body_start + 32])[0]
            else:
                timescale = struct.unpack(">I", data[body_start + 12 : body_start + 16])[0]
                duration = struct.unpack(">I", data[body_start + 16 : body_start + 20])[0]
            return timescale, duration
        if box_type in (b"moov", b"trak", b"mdia"):
            found = _find_mvhd(data, body_start, body_end)
            if found:
                return found
    return None


def mp4_duration_seconds(data: bytes) -> float | None:
    found = _find_mvhd(data, 0, len(data))
    if not found:
        return None
    timescale, duration = found
    if timescale <= 0:
        return None
    return round(duration / timescale, 3)


def resolve_duration(data: bytes, provided: float | None) -> float:
    if provided and provided > 0:
        return round(float(provided), 3)
    parsed = mp4_duration_seconds(data)
    if parsed and parsed > 0:
        return parsed
    return 0.0

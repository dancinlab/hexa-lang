# stdlib/kernels/noc_sim/event_queue.py — D80 g_hexa_only pilot
# companion oracle for `event_queue.hexa`.
#
# Python mirror of the binary min-heap event scheduler. Uses the
# cpython `heapq` stdlib module (which is itself a binary min-heap),
# so the algorithm is byte-identical to the hexa kernel: same
# (time, seq) lex order, same FIFO-at-equal-times semantics, same
# pop sequence for any insert sequence.
#
# The pilot's parity claim is that for ANY sequence of pushes /
# pops, the hexa kernel and this Python oracle return the same
# (time, id, kind, seq) tuples in the same order.
#
# HONESTY (g3): The scheduler IS the algorithm — no measurement.
# `absorbed = false` at the consumer record layer until the demiurge
# HexaNativeParityRef schema lands and a measured external DES
# (BookSim2 event trace, ns-3 packet trace) is wired in.

import heapq


class EventQueue:
    """Min-heap of (time, seq, id, kind) tuples. `seq` is the
    monotone insertion counter that breaks ties at equal times —
    guarantees FIFO at equal times, matching the hexa kernel."""

    __slots__ = ("_heap", "_next_seq")

    def __init__(self):
        self._heap = []
        self._next_seq = 0

    def push(self, time: float, id: int, kind: int) -> None:
        seq = self._next_seq
        self._next_seq += 1
        # heapq orders tuples lexicographically — (time, seq) gives
        # exactly the hexa kernel's _ev_less ordering.
        heapq.heappush(self._heap, (time, seq, id, kind))

    def pop(self):
        """Returns (time, id, kind, seq) or (-1.0, -1, -1, -1) when
        empty — same sentinel convention as the hexa kernel."""
        if not self._heap:
            return (-1.0, -1, -1, -1)
        time, seq, id_, kind = heapq.heappop(self._heap)
        return (time, id_, kind, seq)

    def peek(self):
        if not self._heap:
            return (-1.0, -1, -1, -1)
        time, seq, id_, kind = self._heap[0]
        return (time, id_, kind, seq)

    def size(self) -> int:
        return len(self._heap)

    def empty(self) -> bool:
        return not self._heap


def _smoke():
    """Demonstration trace — the same sequence the hexa test runs."""
    q = EventQueue()
    # Insert out of order; expect pops in (time, seq) order.
    q.push(2.0, 100, 0)
    q.push(1.0, 101, 0)
    q.push(3.0, 102, 0)
    q.push(1.0, 103, 0)   # tie at t=1.0; seq=3 > seq=1, so pops AFTER 101
    q.push(0.5, 104, 0)
    print(f"size after 5 pushes: {q.size()}")
    while not q.empty():
        t, id_, kind, seq = q.pop()
        print(f"  pop t={t} id={id_} kind={kind} seq={seq}")


if __name__ == "__main__":
    _smoke()

import sync

var q = newMpscQueue[string]()
var n = ""
assert q.dequeue(n) == false

q.enqueue(")")
q.enqueue(")")

assert q.dequeue(n)
assert n == ")"

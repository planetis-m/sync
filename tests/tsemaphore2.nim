import sync

var
  semS, semT: Semaphore
  aArrived, cArrived = false
  thread: Thread[void]

proc routine =
  # Section C
  cArrived = true
  signal semT
  wait semS
  # Section D
  assert aArrived, "Constraint: Section A precedes D"

proc testSemMultiResource =
  # Parent and child both get in the critical section at the same
  # time, and shake hands.
  initSemaphore semS
  initSemaphore semT
  createThread(thread, routine)
  # Section A
  aArrived = true
  signal semS
  wait semT
  # Section B
  assert cArrived, "Constraint: Section C precedes B"
  joinThread thread

testSemMultiResource()

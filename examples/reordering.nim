# https://preshing.com/20120515/memory-reordering-caught-in-the-act/
# https://www.youtube.com/watch?v=nh9Af9z7cgE

import std/strformat, sync

var
  t1, t2: Thread[void]
  # Semaphores for signaling threads
  s1, s2: Semaphore
  e: Semaphore
  # Variable for memory re-ordering
  v1, v2 = 0
  r1, r2 = 0

proc reorder1 =
  # Keep going forever
  while true:
    # Wait for the signal to start
    s1.wait()
    # Write to v1
    v1 = 1
    # Barrier to prevent re-ordering in the hardware!
    #atomicThreadFence(AtomicSeqCst)
    # Read v2
    r1 = v2
    # Say we're done for this iteration
    e.signal()

proc reorder2 =
  # Keep going forever
  while true:
    # Wait for the signal to start
    s2.wait()
    # Write to v2
    v2 = 1
    # Barrier to prevent re-ordering in the hardware!
    #atomicThreadFence(AtomicSeqCst)
    # Read v1
    r2 = v1
    # Say we're done for this iteration
    e.signal()

proc main =
  init(s1)
  init(s2)
  init(e)

  # Start threads
  createThread(t1, reorder1)
  createThread(t2, reorder2)

  var i = 0
  while true:
    inc i
    # Re-initialize the shared variables
    v1 = 0
    v2 = 0
    # Signal the threads to start
    s1.signal()
    s2.signal()
    # Wait for them to finish
    e.wait()
    e.wait()
    # Check of both read values bypassed the loads
    if r1 == 0 and r2 == 0:
      echo &"ERROR! R1 = {r1}, R2 = {r2}, ITER {i}"
      doAssert false
    else:
      echo &"ALL GOOD! R1 = {r1}, R2 = {r2}"
  #joinThread(t1)
  #joinThread(t2)

main()

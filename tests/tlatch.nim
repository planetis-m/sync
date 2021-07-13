import sync

var
  latch: Latch

# test zero count latch
proc test =
  init latch, 0
  # wait should not block
  wait(latch)
  # decriment should have no effect
  dec(latch)
  dec(latch)
  # wait should not block
  wait(latch)

test()

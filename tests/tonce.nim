import sync

var o: Once
proc smokeOnce() =
  initOnce o
  var a = 0
  o.once(a += 1)
  assert a == 1
  o.once(a += 1)
  assert a == 1

smokeOnce()

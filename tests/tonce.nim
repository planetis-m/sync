import sync

var o: Once
proc smokeOnce() =
  var a = 0
  o.once(a += 1)
  assert a == 1
  o.once(a += 1)
  assert a == 1

smokeOnce()

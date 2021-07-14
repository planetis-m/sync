import sync/atomics2

block testSize: # issue 12726
  type
    Node = ptr object
      # works
      next: Atomic[pointer]
      f: Atomic[bool]
    MyChannel = object
      # type not defined completely
      back: Atomic[ptr int]
      f: Atomic[bool]
  static:
    assert sizeof(Node) == sizeof(pointer)
    assert sizeof(MyChannel) == sizeof(pointer) * 2

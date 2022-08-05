import nake, std/strformat

task "docs", "Generate documentation":
  # https://nim-lang.github.io/Nim/docgen.html
  let
    sync = "sync"
    src = [
      sync.addFileExt(".nim"),
      sync / "atomics2.nim", sync / "barrier.nim",
      sync / "latch.nim", sync / "once.nim",
      sync / "rwlock.nim", sync / "semaphore.nim",
      sync / "smartptrs.nim", sync / "spinlock.nim",
      sync / "spsc.nim", sync / "spsc_queue.nim"
    ]
    dir = "docs/"
    doc = dir / sync.addFileExt(".html")
    url = "https://github.com/planetis-m/sync"
  if doc.needsRefresh(src):
    echo "Generating the docs..."
    direShell(nimExe,
        &"doc --threads:on --project --verbosity:0 --git.url:{url} --git.devel:master --git.commit:master --out:{dir} {src[0]}")
    withDir(dir):
      moveFile("theindex.html", "index.html")
  else:
    echo "Skipped generating the docs."

task "test", "Run the tests":
  withDir("tests/"):
    for f in walkFiles("t*.nim"):
      echo "Running test ", f, "..."
      direShell(nimExe,
          "c -r --gc:orc --panics:on --threads:on --threadanalysis:off --tlsEmulation:off --hints:off -w:off --path:../", f)

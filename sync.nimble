# Package

version     = "1.5.0"
author      = "Antonis Geralis"
description = "Useful synchronization primitives."
license     = "MIT"

# Deps

requires "nim >= 1.0.0"

import os

const
  ProjectUrl = "https://github.com/planetis-m/sync"
  PkgDir = thisDir().quoteShell
  DocsDir = PkgDir / "docs"

task docs, "Generate documentation":
  # https://nim-lang.github.io/Nim/docgen.html
  withDir(PkgDir):
    let src = "sync.nim"
    # Generate the docs for {src}
    exec("nim doc --verbosity:0 --git.url:" & ProjectUrl &
        " --git.devel:main --git.commit:main --out:" & DocsDir & " " & src)
    # mvFile("theindex.html", "index.html")

task test, "Run the tests":
  withDir(PkgDir):
    for f in listFiles("tests"):
      if f.endsWith(".nim"):
        echo "Running ", f, "..."
        exec("nim c -r --cc:clang --panics:on --threadanalysis:off --tlsEmulation:off" &
            " -d:useMalloc -t:\"-fsanitize=thread\" -l:\"-fsanitize=thread\" -d:nosignalhandler" &
            " --hints:off -w:off " & quoteShell(f))

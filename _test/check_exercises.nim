import critbits, os, osproc, parseopt, strutils

## This file is for testing the Nim track of exercism.io.
##
## It checks that the example solution for every implemented exercise passes
## that exercise's test suite.
##
##
## Usage
## =====
## Test all the exercises:
## - `nim c -r check_exercises.nim`
##
## Test a selection of exercises:
## - `nim c -r check_exercises.nim [exercise-name] [...]`
##
##
## Implementation
## ==============
## Running this file will:
## 1) Copy tests and examples from the standardized Exercism directory structure
##    into an output directory with a valid Nimble structure.
##
## 2) Write the following files:
##    - `all_tests.nim` (imports every test).
##    - `config.nims`   (modifies the path for the tests).
##
## 3) Run `all_tests.nim`.
##
##
## Output directory structure
## ==========================
## ```
## check_exercises_tmp
## ├── src
## │   └── check_exercises
## │       ├── acronym.nim
## │       ...
## │       └── yacht.nim
## ├── tests
## │   ├── all_tests.nim
## │   ├── config.nims
## │   ├── test_acronym.nim
## │   ...
## │   └── test_yacht.nim
## ```

let
  appDir = getAppDir()
  exercisesDir = appDir / "../exercises"
  outDir = appDir / "check_exercises_tmp"
  testDir = outDir / "tests"
  srcDir = outDir / "src" / "check_exercises"
  allTestsPath = testDir / "all_tests.nim"

# Let us define the exercise names as a set of strings. This is simpler than
# defining an `enum` of all exercises (or all implemented exercises). We can use
# `CritBitTree[void]` - an efficient container for a sorted set of strings.
type
  Slugs = CritBitTree[void]

proc getImplementedSlugs: Slugs =
  ## Returns the names of the implemented exercises.
  ##
  ## Let us consider an "implemented exercise" as one with a correctly named
  ## test file, rather than one with an entry in `config.json`. This can be more
  ## convenient when implementing new exercises.
  for _, dir in walkDir(exercisesDir):
    for file in walkFiles(dir / "*_test.nim"):
      result.incl(dir.splitPath().tail) # e.g. "hello-world"

proc prepareDir =
  ## Creates the new directory structure for the tests.
  removeDir(outDir)
  createDir(testDir)
  createDir(srcDir)
  const configFileContents = "--path: \"$projectDir/../src/check_exercises\""
  writeFile(testDir / "config.nims", configFileContents)

proc wrapTest(file: string, slug: string): string =
  ## Returns the contents of `file`, but with the tests wrapped inside a proc.
  ##
  ## This is a workaround for the "too many global variables" error when running
  ## many top-level tests with `unittest`. It allows us to keep top-level
  ## `suite` statements in the repository's test files, which keeps them as
  ## clear as possible for the user.
  ##
  ## We need this workaround as the `suite` and `test` templates in `unittest`
  ## otherwise put every variable in the global scope, and Nim's GC sets a limit
  ## of 3500 global variables.
  var inSuite = false
  let origFile = readFile(file)
  let numSuites = origFile.count("\nsuite \"")
  # Allocate a longer string for the wrapped tests.
  result = newStringOfCap((origFile.len.float * 1.15).int)

  # Add one indentation layer to all lines from "suite" onwards.
  for line in lines(file):
    if line.len == 0:
      result &= "\n"
    elif line.startsWith("suite \""):
      # Put all the tests for an exercise into one suite.
      if not inSuite:
        inSuite = true
        result &= "proc main =\n"
        result &= "  suite \"" & slug & "\":\n"
      # If there are multiple suites, keep the suite names as comments only.
      if numSuites > 1:
        result &= "    # " & line[7 .. ^3] & "\n"
    elif inSuite:
      result &= "  " & line & "\n"
    else:
      result &= line & "\n"
  result &= "\nmain()\n"
  # The below suppresses an "unused import" warning that is otherwise generated
  # for each exercise. We run each module's `main` proc when importing, but we
  # don't export any of its symbols.
  result &= "{.used.}\n"

proc prepareTests(slugs: Slugs) =
  ## Copies the example solution and a wrapped test file for the exercises in
  ## `slugs`, and writes a file that joins all the tests for these exercises.
  ##
  ## This allows us to compile `system.nim` and other dependencies only once,
  ## rather than per-exercise, which fixes the main performance bottleneck when
  ## testing multiple exercises. It also improves convenience by printing all
  ## compiler warnings and hints at the top of the output.
  var allTests = "import ../tests/[\n"

  for slug in slugs:
    let slugUnder = slug.replace("-", "_")
    let testName = "test_" & slugUnder # e.g. "test_hello_world"
    allTests &= "  " & testName & ",\n"
    let dir = exercisesDir / slug

    # Copy and rename the example solution. For example:
    #   `exercises/bob/example.nim`  ->  `outDir/src/check_exercises/bob.nim`
    copyFile(dir / "example.nim", srcDir / slugUnder & ".nim")

    # Copy a wrapped version of the test. For example:
    #   `exercises/bob/bob_test.nim`  ->  `outDir/tests/test_bob.nim`
    let wrappedTest = wrapTest(dir / slugUnder & "_test.nim", slug)
    writeFile(testDir / testName & ".nim", wrappedTest)

  allTests &= "]\n"
  writeFile(allTestsPath, allTests)

proc runTests(slugs: Slugs): int =
  ## Runs the tests for the exercises in `slugs`.
  ##
  ## Returns the exit code, which is `0` if all tests pass and `1` otherwise.
  prepareDir()
  prepareTests(slugs)

  result = execCmd("nim c -r --styleCheck:hint " & allTestsPath)
  if result == 0:
    let wording = if slugs.len == 1: " exercise." else: " exercises."
    echo "\nTested ", slugs.len, wording, "\nAll tests passed."
  else:
    echo "\nFailure. At least one test failed."

proc parseCmdLine: Slugs =
  ## Returns the user-specified exercise slugs.
  let implementedSlugs = getImplementedSlugs()

  for kind, key, val in getopt():
    case kind
    of cmdShortOption, cmdLongOption:
      discard
    of cmdArgument:
      if key in implementedSlugs:
        result.incl(key) # Test specified exercises in the order given.
      else:
        echo "Error: unrecognized exercise name: '" & key & "'"
        quit(0)
    of cmdEnd: assert(false) # Cannot happen.

  if result.len == 0:
    result = implementedSlugs # Test all exercises (in alphabetical order).

when isMainModule:
  let slugs = parseCmdLine()
  let exitCode = runTests(slugs)
  if exitCode != 0:
    quit(exitCode)

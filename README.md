# SPFKTesting

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-testing)](https://github.com/ryanfrancesconi/spfk-testing/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-testing%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-testing)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-testing%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-testing)

Test infrastructure. Every Spongefork package's test targets depend on it, and nothing else should.

It ships shared media fixtures, covering every container the packages read and resolved the same way
under `xcodebuild` and `swift test`; the Swift Testing tags the workspace's test plans select on;
readers that parse each container's bytes directly, sharing no code with any metadata library, so a
test can check what a writer actually wrote; and a separate `SPFKBench` library for timing and
regression records in release benchmark executables.

The code that declares the fixtures and tags is the reference for what exists.

## Writing tests against it

- Derive a fixture's properties from the file, such as sample rate, duration and channel count. The
  fixtures do not share them, and a hardcoded value turns a correct result into a confident failure.
- Copy a fixture before writing to it. `BinTestCase` in spfk-base gives each test its own temporary
  directory.
- The tabla series is one performance in many formats, so members can be checked against each other,
  but a lossy member can be offset by encoder priming: compare position, not samples.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).

# SPFKTesting

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-testing)](https://github.com/ryanfrancesconi/spfk-testing/tags)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-testing%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-testing)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-testing%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-testing)

Shared test infrastructure for Spongefork packages: media fixtures, Swift Testing tags, and readers
that parse container bytes directly, independent of any metadata library.

## Features

- Bundled audio, image and video fixtures, resolved the same way under `xcodebuild` and `swift test`
- Swift Testing tags used by the test plans
- Byte-level readers for RIFF, AIFF, ID3v2, MP4, FLAC, Ogg, Vorbis comments and Matroska, so a test
  can check what a writer actually wrote
- Memory retention measurement (`retainedMemoryMB`)
- `SPFKBench`, a separate library for timing and regression records in benchmark executables

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).

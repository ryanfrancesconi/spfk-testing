# SPFKTesting

A Swift package providing shared test resources and utilities for all SPFK test targets. Bundles a catalog of audio and image files used across the SPFK ecosystem, with platform-aware resource resolution for macOS and iOS.

## Overview

SPFKTesting provides two main components:

- **`TestBundleResources`** — A `Sendable` singleton exposing 30+ named audio and image test files organized into collections by purpose (format coverage, metadata markers, edge cases).
- **`Tag` extensions** — Custom Swift Testing tags (`development`, `file`, `automation`, `realtime`, `engine`) for categorizing tests across SPFK modules.

## Key Types

### TestBundleResources

Singleton providing typed access to bundled test resources. Used by downstream packages for audio format testing, metadata parsing, and file I/O validation.

```swift
let resources = TestBundleResources.shared

// Access individual files
let wav = resources.tabla_wav
let mp3 = resources.mp3_id3

// Iterate format collections
for url in resources.formats {
    // tabla.aac, tabla.aif, tabla.caf, tabla.flac,
    // tabla.m4a, tabla.mp3, tabla.mp4, tabla.ogg, tabla.wav
}

for url in resources.markerFormats {
    // Formats supporting RIFF/Chapter markers and metadata
}

for url in resources.audioCases {
    // Diverse set for broad audio testing
}
```

### BundleResources

Generic resource resolver that maps file names to URLs within a bundle. Handles platform-specific bundle directory structures (macOS `Contents/Resources` vs iOS bundle root).

```swift
let br = BundleResources(bundleURL: Bundle.module.bundleURL)
let url = br.resource(named: "tabla.wav")
```

### Test Tags

Custom tags for filtering test execution in Swift Testing test plans:

```swift
@Test(.tags(.file))
func readWavMetadata() { ... }

@Test(.tags(.realtime))
func displayLinkTiming() { ... }
```

## Bundled Resources

### Audio (24 files)

| Resource | Purpose |
|----------|---------|
| `tabla.*` (9 formats) | Format coverage: AAC, AIF, CAF, FLAC, M4A, MP3, MP4, OGG, WAV |
| `tabla_6_channel.wav` | Multi-channel audio |
| `and-oh-how-they-danced.mp3` | ID3 metadata |
| `and-oh-how-they-danced.wav` | BEXT v2 metadata |
| `and-oh-how-they-danced_2.wav` | BEXT v2 variant |
| `123456789_60BPM_48k.wav` | BEXT v1, tempo reference |
| `cowbell.wav` | General audio |
| `cowbell_bext.wav` | BEXT metadata |
| `pink_noise.wav` | Signal processing reference |
| `no metadata.mp3` | No metadata edge case |
| `xmp.mp3` | XMP metadata |
| `toc_many_children.mp3` | Complex TOC structure |
| `no_data_chunk.wav` | Missing data chunk edge case |
| `usesEntireiXMLSpec.wav` | Full iXML specification |
| `boom.addAudio` | Custom extension (M4A internally) |

### Images (1 file)

| Resource | Purpose |
|----------|---------|
| `sharksandwich.jpg` | Image metadata testing |

## Architecture

```
Sources/SPFKTesting/
  ├── BundleResources.swift        — Generic bundle resource resolver (macOS/iOS)
  ├── TestBundleResources.swift    — Singleton with named audio/image properties
  ├── Tags+.swift                  — Swift Testing tag extensions
  └── Resources/
      ├── audio/                   — 24 audio test files
      └── image/                   — 1 image test file
```

## Usage

Add SPFKTesting as a dependency in your test target only:

```swift
.testTarget(
    name: "MyPackageTests",
    dependencies: ["SPFKTesting"]
)
```

## Requirements

- macOS 12+
- Swift 6.2+

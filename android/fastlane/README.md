fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android release

```sh
[bundle exec] fastlane android release
```

Build the arm64-v8a direct release APK, write version.json and upload both over SSH

### android manifest

```sh
[bundle exec] fastlane android manifest
```

Write version.json from pubspec.yaml (no build, no upload) — for previewing

### android beta

```sh
[bundle exec] fastlane android beta
```

Build the play-flavor AAB and upload it to Google Play (open testing/beta track)

### android production

```sh
[bundle exec] fastlane android production
```

Build the play-flavor AAB and upload it to Google Play (production track)

### android ship

```sh
[bundle exec] fastlane android ship
```

Release everywhere: self-hosted direct APK + manifest, then Google Play production

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios release

```sh
[bundle exec] fastlane ios release
```

Release: upload screenshots and submit for review (metadata is NOT touched)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots only to App Store Connect (no metadata, no submission)

### ios submit_for_review

```sh
[bundle exec] fastlane ios submit_for_review
```



### ios update_metadata

```sh
[bundle exec] fastlane ios update_metadata
```

Upload metadata only to App Store Connect (no screenshots, no binary, no submission)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

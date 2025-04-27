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

### ios tests

```sh
[bundle exec] fastlane ios tests
```

Run all tests

### ios build

```sh
[bundle exec] fastlane ios build
```

Build app for development

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Submit a new Beta Build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Deploy a new version to the App Store

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

スクリーンショットを生成

### ios update_metadata

```sh
[bundle exec] fastlane ios update_metadata
```

App Store Connectのメタデータのみを更新

### ios update_screenshots

```sh
[bundle exec] fastlane ios update_screenshots
```

App Store Connectのスクリーンショットのみを更新

### ios update_store

```sh
[bundle exec] fastlane ios update_store
```

App Store Connectのメタデータとスクリーンショットを更新

### ios download_from_store

```sh
[bundle exec] fastlane ios download_from_store
```

App Store Connectから現在のメタデータとスクリーンショットをダウンロード

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

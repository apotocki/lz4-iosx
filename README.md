## LZ4 for iOS and Mac OS X (Intel & Apple Silicon) - arm64 / x86_64

Supported versions: [1.9.4](https://github.com/apotocki/lz4-iosx/tree/1.9.4)


This repo provides a universal script for building a static liblz4 library for use in iOS and Mac OS X applications.

## Prerequisites

1. **Install Xcode**: Ensure Xcode is installed, as `xcodebuild` is required to create `xcframeworks`.

2. **Verify Xcode Developer Directory**:
   - The `xcode-select -p` command must point to the Xcode app's developer directory (e.g., `/Applications/Xcode.app/Contents/Developer`).
   - If it points to the CommandLineTools directory, reset it using one of the following commands:
     ```bash
     sudo xcode-select --reset
     ```
     or
     ```bash
     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
     ```

3. **Install Required SDKs**: To build for tvOS, watchOS, visionOS, and their simulators, make sure the corresponding SDKs are installed in the folder:
```
   /Applications/Xcode.app/Contents/Developer/Platforms
```

4. **Install CMake**: CMake (at least version 3.10) must be installed, e.g., via `brew install cmake`.

## Build Manually
```
    # clone the repo
    git clone https://github.com/apotocki/lz4-iosx
    
    # build libraries
    cd lz4-iosx
    scripts/build.sh
    
    # the result artifacts will be located in 'frameworks' folder.
    # Then you can add the xcframework to your Xcode project. The process is described, e.g., at https://www.simpleswiftguide.com/how-to-add-xcframework-to-xcode-project/
```
## Selecting Platforms and Architectures
build.sh without arguments builds xcframeworks for iOS, macOS, Catalyst and also for watchOS, tvOS, visionOS if their SDKs are installed on the system. It also builds xcframeworks for their simulators with the architecture (arm64 or x86_64) depending on the current host.
If you are interested in a specific set of platforms and architectures, you can specify them explicitly using the -p argument, for example:
```
scripts/build.sh -p=ios,iossim-x86_64
# builds xcframeworks only for iOS and iOS Simulator with x86_64 architecture
```
Here is a list of all possible values for '-p' option:
```
macosx,macosx-arm64,macosx-x86_64,macosx-both,ios,iossim,iossim-arm64,iossim-x86_64,iossim-both,catalyst,catalyst-arm64,catalyst-x86_64,catalyst-both,xros,xrossim,xrossim-arm64,xrossim-x86_64,xrossim-both,tvos,tvossim,tvossim-arm64,tvossim-x86_64,tvossim-both,watchos,watchossim,watchossim-arm64,watchossim-x86_64,watchossim-both
```
Suffix '-both' means that xcframeworks will be built for both arm64 and x86_64 architectures.
The platform names for macosx and simulators without an architecture suffix (e.g. macosx, iossim, tvossim) mean that xcframeworks are only built for the current host architecture.

## Rebuild option
To rebuild the libraries without using the results of previous builds, use the --rebuild option
```
scripts/build.sh -p=ios,iossim-x86_64 --rebuild

```

## Build Using CocoaPods
Add the following lines to your project's Podfile:
```
    use_frameworks!
    pod 'lz4-iosx'
    # or optionally more precisely e.g.:
    # pod 'lz4-iosx', :git => 'https://github.com/apotocki/lz4-iosx'
```
Then install the dependencies:
```
   pod install --verbose
```

## As an advertisement...
The LZ4 XCFramework built by this project is used in my iOS application on the App Store:

<table align="center" border="0" cellspacing="0" cellpadding="0">
  <tr>
    <td>
      <a href="https://apps.apple.com/us/app/potohex/id1620963302">
        <img src="https://is4-ssl.mzstatic.com/image/thumb/Purple112/v4/78/d6/f8/78d6f802-78f6-267a-8018-751111f52c10/AppIcon-0-1x_U007emarketing-0-10-0-85-220.png/460x0w.webp" width="70" />
      </a>
    </td>
    <td>
      <a href="https://apps.apple.com/us/app/potohex/id1620963302">PotoHEX</a><br />
      HEX File Viewer &amp; Editor
    </td>
  </tr>
</table>

PotoHEX is designed for viewing and editing files at the byte or character level, calculating hashes, encoding/decoding data, and compressing/decompressing selected byte ranges.

If you find this project useful, you can support my open-source work by trying the [App](https://apps.apple.com/us/app/potohex/id1620963302).

---

Feedback is welcome!

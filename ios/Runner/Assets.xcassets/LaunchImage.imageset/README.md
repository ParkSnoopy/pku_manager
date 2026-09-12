# iOS Launch Image Asset

`Contents.json` maps `LaunchImage.png`, `LaunchImage@2x.png`, and `LaunchImage@3x.png` to the universal 1×, 2×, and 3× launch-image slots.

Replace all three scale variants together and preserve their filenames and `Contents.json` mapping. Xcode edits must target `ios/Runner.xcworkspace` → `Runner/Assets.xcassets/LaunchImage.imageset`.
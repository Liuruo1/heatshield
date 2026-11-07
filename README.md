# heatshield

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS and Apple Watch CI artifact

The `iOS + watchOS Unsigned IPA` GitHub Actions workflow runs on pushes to
`main` and can also be started manually. Download the
`heatshield-ios-watch-unsigned-ipa` artifact from a completed workflow run. It
contains an unsigned IPA with the Apple Watch companion embedded.

The IPA is unsigned and is not directly installable or suitable for App Store
distribution. Sideloading requires signing it with a valid Apple development
certificate and provisioning profile for the iPhone and paired watch.

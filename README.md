# obssource

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## OBS source configuration

The OBS source JSON can select the renderer used by the complete follow
animation:

```json
{
  "follow_animation_renderer": "optimized",
  "follow_avatar_resolution": 48
}
```

Supported values are `optimized` (the default `drawRawAtlas` renderer) and
`legacy` (the previous canvas renderer). The avatar resolution defaults to
`48`; its pixel size remains fixed at `8`.

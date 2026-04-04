# Example App

This app is a manual integration demo for `iwb_canvas_engine`. It is intended
to exercise the public runtime API, not to serve as a reusable UI template.

## What it demonstrates

- `SceneView` + `SceneController` wired through a real Flutter screen
- Move mode: selection, marquee, drag move, rotate, flip, delete, and clear
- Draw mode: pen, highlighter, line (drag and two-tap), and eraser
- Inline text editing via `editTextRequests`
- Background color, grid settings, and camera offset controls
- JSON export/import through the public codec
- Sample image nodes rendered through `imageResolver`

## Run

From the package root:

```sh
cd example
flutter run
```

Use `flutter devices` and `flutter run -d <deviceId>` if you want a specific
target.

## Windows installer artifact

This repository includes a manual GitHub Actions workflow named
`Windows Installer`.

It builds the Flutter Windows desktop release for `example/`, packages the
release directory into an Inno Setup installer, and uploads a `setup.exe`
artifact.

Use it when you want a Windows-installable package for smoke-testing install
and launch behavior on a real machine.

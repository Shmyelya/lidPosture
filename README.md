# lidPosture

macOS menu bar app that tracks sitting posture with the built-in webcam and compensates for MacBook lid tilt so adjusting the screen does not look like slouching.

## Requirements

- macOS 13+
- Xcode 15+ (Swift 5)
- Camera access
- Lid-angle compensation only on MacBooks that expose the HID sensor (best-effort; app still works without it)

## Build & Run

```bash
open LidPosture.xcodeproj
```

Select the **LidPosture** scheme, then Run. Grant camera (and notification) access when prompted.

Optional: regenerate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
```

## First use

1. Sit upright for a couple of seconds and press **Calibrate** (⌘K).
2. Slouch — after ~15 seconds you should get a notification.
3. Without moving your head, tilt the lid; the “head drop” reading should stay roughly stable. If it drifts worse, flip `lidCompensationSign` in `PostureEngine.swift` and/or tune `verticalFOV`.

## Layout

| File | Role |
|---|---|
| `LidAngleSensor.swift` | Lid angle via undocumented HID (IOKit) |
| `FaceTracker.swift` | 640×480 camera + Vision face bounds (~2 Hz) |
| `PostureEngine.swift` | Calibration, lid compensation, verdict |
| `AppState.swift` | Wiring, alert delay/cooldown, notifications |
| `LidPostureApp.swift` | `MenuBarExtra` UI |

## Privacy

Camera frames are processed on-device for face bounds. Video is not recorded or uploaded.

## License

MIT

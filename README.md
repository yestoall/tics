# TICS

[Leer en español](README.es.md)

Make your Mac sound like a mechanical keyboard when you type, and like a mouse when you click.

Version 0.1.1

[![Watch TICS on YouTube, with sound](https://img.youtube.com/vi/_GZCnr1pWfg/maxresdefault.jpg)](https://youtu.be/_GZCnr1pWfg)

**[Watch it on YouTube](https://youtu.be/_GZCnr1pWfg)**, with sound on.

## Download

**[Download TICS](https://github.com/yestoall/tics/releases/latest/download/TICS.dmg)**, free.
Open the .dmg and drag TICS to Applications. It needs macOS 14 or later and works on Apple
silicon and Intel Macs. The first time you open it, macOS asks for permission to listen to the
keyboard.

## What it does

TICS lives in the menu bar. Every key you press, in any app, plays the sound of the keyboard you
choose.

- **11 keyboards**: Cherry MX Blue, Brown and Red, Holy Panda, Cream, MX Blue, MX Brown, Oreo,
  Topre Purple, Turquoise, and a synthetic one generated in code.
- **Press and release** sound different, and holding a key down sounds softer on each repeat.
- **Clicks, drags and scrolling**: your mouse makes sounds too, at the same volume as your
  keyboard. Dragging sounds like a ratchet, faster the quicker you move, and the scroll wheel
  clicks with every notch.
- **Mouse Settings**: set the pitch, volume and how dry or hollow each button, dragging and the
  scroll wheel sound, and hear them as you go.
- **Logitech mice**: if Logi Options+ takes over a button (back, forward, gestures…), turn on the
  Logitech tile and it makes a sound too. Works with the mouse connected over Bluetooth. With an
  MX Master 4, each button can also vibrate when you press it, with the effect you pick in Mouse
  Settings.
- **English and Spanish**: TICS follows your Mac's language.

## Privacy

TICS needs **Input Monitoring** permission to know which key you press and pick its sound. It
only listens: it never saves what you type or where you click, and it never connects to the
internet.

With the Logitech tile on, TICS also asks for **Bluetooth** permission, to hear the buttons
Logi Options+ takes over. It only listens for when you press and release them: it doesn't change
anything on your mouse.

## Build

You need macOS 14 or later and Swift 6 (Xcode or its command line tools).

```bash
bun run dev     # debug build, then opens the app
bun run build   # release build: build/Tics.app
bun run test    # the tests
```

Without Bun: `scripts/build-app.sh release && open build/Tics.app`.

The app is signed with your “Apple Development” certificate if you have one, or with any identity
you set in `SIGN_IDENTITY`. Without a certificate it's signed ad hoc: it works the same, but macOS
asks for the permission again after every build.

## Sounds

The keyboards use the [Mechvibes](https://github.com/hainguyents13/mechvibes) format and come
from two MIT-licensed projects:

- [Mechvibes](https://github.com/hainguyents13/mechvibes): Oreo, Cherry MX Blue, Brown and Red,
  and Topre Purple. License in `Resources/SoundPacks/LICENSE-mechvibes`.
- [kbsim](https://github.com/tplai/kbsim): Holy Panda, Cream, MX Blue, MX Brown and Turquoise.
  Each folder includes its license.

Mouse clicks and the synthetic keyboard don't come from any file: TICS generates them on the fly.

## License

[MIT](LICENSE).

designed with ♥ by [@yestoall](https://yestoall.com)

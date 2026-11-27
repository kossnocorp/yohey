# Yohey

A SwiftUI menu-bar app for macOS 13 and later. **Match system settings** is on
by default: Yohey checks the battery and adapter display-off timers and the
password delay every minute. Uncheck it to edit those values, or use refresh
to copy them once. Click the bell for **Lock reminders**, **Play sound**,
**Flash screen**, and **Preferences…**. Option-click it for live display-off and
password-lock countdowns. Release Option after opening; close the popup to stop
live updates. Right-click or Control-click the bell to toggle all lock reminders
without opening the menu. A checkmark means the option is on; selecting it
toggles the option and closes the menu. Background checks are scheduled around potential reminders.
Brightness may dim earlier; macOS does not report that deadline here.
When an app such as Amphetamine prevents idle display sleep, the Option-click view shows
**Kept awake**. Display-based reminders pause until the last app
releases its hold, then resume using current idle time. A separate screen-saver
lock deadline still counts down.

By default Yohey chimes 60, 30 and 10 seconds before the estimated **password lock**.
In Preferences you can set the first reminder (15 seconds to 10 minutes before
lock), the number of reminders (1–100), and their playback volume. Choose
**Steady** for equal gaps, **Gentle build-up** for gradually shorter gaps
(the default), or **Urgent build-up** for chimes concentrated near lock.
The first chime uses **Start volume** and the last uses **End volume**;
intermediate chimes follow the selected spacing curve. Equal levels keep
volume constant. Preview and single-reminder schedules use End volume.
Enable **Flash screen** for a brief visual cue on each display at
the same reminder times. Flashes are spaced at least 0.35 seconds apart on dense
schedules. This option is off by default and works with sound muted.
The first observed display-off or screen-saver start anchors the password
grace period. Real input resets the idle cycle. A password setting of **Never**
silences lock reminders. Yohey can chime while only the display is off, but
cannot play sounds during system sleep. It never generates input or keeps the
Mac awake. See [Apple’s Lock Screen settings guide](https://support.apple.com/guide/mac-help/change-lock-screen-settings-on-mac-mh11784/mac).

## Develop

Install full Xcode (16 or later) and mise. From the repo root:

```sh
mise trust
mise trust pkgs/website/mise.toml
mise install
mise test           # idle-cycle, reset and missed-warning tests
mise build          # universal, locally signed app
mise dev            # rebuild, quit any running Yohey, and launch the new build
```

Settings are saved as you change them. Enable **Start on login** in Preferences
to have macOS launch Yohey when you sign in.

Open Preferences to choose a built-in macOS alert sound, preview it, or change
the timeout. Yohey remembers your sound choice (default: Sosumi). For a
quick manual check, uncheck **Match system settings** and set the active
limit to 1 minute and the password delay to Immediately: expect chimes at 30 and 50
seconds of inactivity. Move the mouse between chimes and check that the
countdown starts again. Check actual display sleep separately against your
Mac’s Lock Screen settings.

## Install a release

Use the website installer or the `install.sh` attached to the GitHub release.
It checks the archive checksum and Developer ID signature, installs the bundle
at `${XDG_DATA_HOME:-$HOME/.local/share}/yohey/Yohey.app`, and writes a
launcher to `${XDG_BIN_HOME:-$HOME/.local/bin}/yohey`. Run the launcher to
start the app. To uninstall, quit Yohey and remove those two items.

## Sign, notarize, publish

See [HUMANS.md](HUMANS.md) for Apple credentials, fnox, GitHub environments
and the first release. For a local release build with your signing identity
in Keychain:

```sh
mise exec -- fnox exec -- mise run notarize:setup
mise exec -- fnox exec -- mise notarize
```

The stapled archive is `build/Yohey-notarized.zip`. GitHub runs the same build
on `app@X.Y.Z`, taking the app version from the tag.
To roll back an app release, run `mise run //:release/app:rollback X.Y.Z`.
This removes the GitHub release (if published) and its remote and local tags,
leaving commits intact. It also works when CI failed before publishing.

## Website

```sh
mise exec -- pnpm install --frozen-lockfile
mise //pkgs/website:dev
mise //pkgs/website:build
```

The static Astro site deploys to Cloudflare Workers at [yohey.fyi](https://yohey.fyi). `/install.sh` redirects
to the latest release installer; the installer itself pins its release version.
From a clean commit, `mise run //:release:website` creates the next local
`website@YYYY-MM-DD.N` tag, pushes the branch, and pushes all local tags.
The website tag triggers the Release Website workflow.

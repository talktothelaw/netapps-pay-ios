# Releasing — iOS

The pod is published by hand, deliberately. Everything else is automatic.

```
bump s.version in NetAppsPaySDK.podspec  →  merge to main
      ↓
GitLab CI: validate   (xcodebuild build, plus tests if the runner has a simulator)
      ↓
GitLab CI: mirror     (pushes branches AND tags to the GitHub repo CocoaPods clones from)
      ↓
you:  git tag 1.1.0 && git push origin 1.1.0     (CI mirrors the tag)
      ↓
you:  pod trunk push NetAppsPaySDK.podspec --allow-warnings
```

`pod trunk push` needs a session token tied to a person, not a CI variable, and
GitLab.com has no free macOS runners — so it stays a one-command manual step.

## The tag is the version

CocoaPods resolves `s.source` at `:tag => s.version.to_s`, so the tag must equal
`s.version` in the podspec **exactly, with no `v` prefix**: `1.1.0`, not
`v1.1.0`. Bump the podspec, merge, then tag that commit.

The tag must reach GitHub before `pod trunk push` — Trunk clones the tag from
the mirror during validation. The `mirror` job does that on every push.

## Current state

`s.version` is `1.1.0`, the `1.1.0` tag exists on GitLab and on the mirror, and
Trunk's newest is `1.0.6`. So `1.1.0` is ready to push whenever you want it.

Check what Trunk has:

```bash
pod trunk info NetAppsPaySDK
```

## `validate` is opt-in until a macOS runner exists

The job needs a runner tagged `macos`. There is none, so its first rule is
`$IOS_VALIDATE_ENABLED != "true" → never`.

This is opt-**in** on purpose. Under opt-out rules the job is still *added* to
every pipeline and sits Pending forever ("no runners that match all of the job's
tags: macos"), and `mirror` — which needs it — waits behind it. That blocks
every release while validating nothing. `needs: optional: true` skips a job that
is **absent** from the pipeline, not one that is **stuck** in it, so the only
way to keep the mirror moving is to keep `validate` out of the pipeline
entirely until a runner exists.

Until then the mirror is **ungated**: releases flow, but nothing builds them
first. To close that hole, provision a macOS runner with Xcode tagged `macos`,
then set `IOS_VALIDATE_ENABLED=true` in Settings → CI/CD → Variables. No code
change needed. The job also has `timeout: 30 minutes` so a runner that
disappears cannot silently hold a release for hours.

`validate` uses `xcodebuild` with an explicit iOS destination, not `swift
build`: the package is iOS-only, and on a Mac host `swift build` targets macOS
and fails on iOS-only API.

## Consequences worth knowing

**Trunk is append-only.** A published version can never be replaced, so
`s.version` must be bumped for every push.

**Rolling back means publishing a higher version.** Consumers pinned to an
exact version are unaffected.

## Release order across the three SDKs

The React Native bridge pins an exact `NetAppsPaySDK` version from CocoaPods
Trunk and refuses to publish if that version is not on Trunk yet. **Push the pod
to Trunk before releasing the RN bridge.**

## CI/CD variables

| Variable | Purpose |
|---|---|
| `MIRROR_SSH_PRIVATE_KEY` | Deploy key with write access to the GitHub mirror |
| `IOS_VALIDATE_ENABLED` | Set to `true` once a `macos` runner exists |

## Verifying a release landed

```bash
git ls-remote --tags https://github.com/talktothelaw/netapps-pay-ios.git
pod trunk info NetAppsPaySDK
```

## 0.2.0 - 2026-11-23

* Added `PerformanceTiming` for step-by-step operation timing reported to
  Firebase Performance, Analytics (slow or failed operations only), and the
  debug console, plus `callTimed` for Cloud Functions and `timeFirstEvent` for
  stream first-load timing.
* Timed session restore, Google, Apple, and email sign-in steps, dynamic form
  loads and submission, and session media loads and uploads.
* Google sign-in on web now always uses the full-page redirect, since desktop
  popups could open behind the browser window.

## 0.1.0 - 2026-11-11

* Added backward-compatible form pages that organize existing sections without
  changing the stored question schema used by older app releases.
* Added page, section, and question editing, reordering, and movement controls.
* Preserved section-only rendering for definitions created by older clients.
* Shared Firebase authentication state mapping to avoid duplicate token-claim
  work across multiple listeners.

## 0.0.1

* Initial reusable authentication, forms, telemetry, and media foundation.

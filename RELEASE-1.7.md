# RAM Play Auto 1.7 — hardware test release

Intercepts playlist jump/index and play/resume before disk audio starts. The
player is stopped, the track selected with LMS's noplay flag, and Daphile's
original ramplay.json start service is called. Daphile owns conversion, queue
replacement and playback. Volume, resampling and DSD settings are unchanged.

Cached RAM URLs and remote streams bypass interception. Status=stop means the
conversion operation is idle, not that playback is outside RAM. The Settings
handler is now registered, and the obsolete activation delay is removed.

Validation: `perl t/ramplay.t` passes 29 assertions using mocked LMS interfaces.
These are not device tests. Actual Daphile and iPeng validation is pending.

## First test

Update to 1.7 from Manage Plugins and restart LMS. Open the plugin Settings page
and check that automatic preparation is enabled. Start one short local PCM album
from stopped playback in iPeng. Wait for RAM processing; expect silence followed
by playback from the beginning. Check Song Info for a RAM play cache URL, then
test next track and pause/resume on cached music. Test DSD separately afterwards.

## Known limitations for this test

- During conversion use Daphile's RAM cancel button. Ordinary iPeng Stop does
  not cancel the independent conversion job, which may subsequently start audio.
- Do not replace/edit the playlist during conversion. Concurrent uncached jumps
  are rejected until the native operation ends.
- Uncached paused tracks restart from the beginning. Cached resume is unchanged.
- Automatic transitions are not intercepted. Queue coverage and RAM capacity
  depend on the native service. The baseline browser test reduced an eight-track
  queue at track five to three cached tracks; completeness needs device testing.
- Use a single unsynchronized player. Sync groups, legacy mode commands and
  other plugins replacing the same dispatch entries are not validated.
- HTTP errors do not trigger audible disk fallback. A 30-minute conversion
  timeout keeps the duplicate-start guard; restart LMS before retrying.
- Do not launch manual RAM processing concurrently with an automatic operation.

## Source references

The upstream LMS Request.pm documents addDispatch wrappers. Commands.pm sends
playlist jump before load_done; its jump handler honours noplay only while
stopped. Sources inspected at LMS-Community/slimserver branch public/9.1.
Native browser behavior inspected on Daphile fw2505251549.

# 1.7.2 - loading feedback (test build)

Adds one four-second showBriefly message: "Daphile RAM Play / Loading into RAM...".
Uses the LMS display notification API, including the jive text block:
https://lyrion.org/reference/slimbrowse/#showbriefly-communications

The notification is sent after the existing RAM start request and exceptions are
ignored. No new dependencies, playback commands, volume changes, progress timers,
or changes to queue handling and polling. Existing v1.7.1 limitations still apply.

iPeng display support is not yet device-tested. The stable repository manifest
continues to offer v1.7.1; this build must not be promoted until a home test confirms
the message appears and playback still stays silent until RAM preparation completes.

Validation: run `perl t/ramplay.t`. Tests include display exceptions during jump,
play and resume, successful request completion, silence, single RAM dispatch,
continued polling and guard release, and no notices for cached/remote playback.

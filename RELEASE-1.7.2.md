# 1.7.2 - loading feedback

Adds a four-second "Daphile RAM Play / Loading into RAM..." notification through LMS showBriefly, including the jive text block.

The notification is sent after the RAM start request; display exceptions are ignored. Playback interception, queue handling, polling and volume settings are unchanged from 1.7.1. No new dependencies.

Validation: 57 automated assertions pass with simulated LMS interfaces and the real JSON decoder, including display failures during jump, play and resume. iPeng and other controllers have not yet been device-tested; visibility depends on client support.

After updating and restarting LMS, start an uncached local album. Check for the initial notice and silence until RAM playback starts. Existing 1.7.1 limitations still apply.

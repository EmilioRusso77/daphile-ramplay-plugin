# Daphile RAM Play Auto 1.7.1

Fixes the v1.7 startup failure on Daphile LMS 9.0.3: `Can't locate Slim/Utils/JSON.pm`.
Uses Perl's standard JSON::PP decoder instead of the nonexistent LMS module.
The tests now load the real JSON decoder and no longer stub the missing dependency.

Retains the playback interception changes and limitations documented for v1.7.
Automated tests cover command handling with simulated LMS interfaces; playback on Daphile/iPeng still requires device validation.

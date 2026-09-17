# Daphile RAM Play Auto 1.7

Prepares local music using Daphile's native RAM Play service before explicit playback, including commands from iPeng.

## Install or update

Add this URL under LMS Manage Plugins → Additional Repositories:

https://raw.githubusercontent.com/EmilioRusso77/daphile-ramplay-plugin/main/DaphileRamPlay/repo.xml

Update the plugin and restart LMS. Open its Settings page to enable automatic RAM preparation.

## Release status and first test

See [release notes and hardware test instructions](../RELEASE-1.7.md). Automated tests pass, but validation on Daphile/iPeng is pending. During conversion, wait or cancel with Daphile's RAM button; ordinary iPeng Stop does not cancel the independent conversion job.

## Implementation

The plugin wraps the documented LMS dispatch commands for playlist jump/index and play/resume. It selects a local uncached track while stopped, then calls the same start endpoint as the browser. Daphile handles the resulting queue and playback. Cached and remote tracks bypass preparation. It does not change volume or audio processing settings.

## Tests

Run `perl t/ramplay.t`. The tests use mocked LMS interfaces and do not replace hardware testing.

## License

MIT, as declared by the original project.

# YASB Checks for New Versions on Startup

## Symptom

YASB checks for new releases on startup and may show an update notification.

## Root Cause

The top-level `update_check` setting in `yasb\config.yaml` was enabled.

## Fix

Disable the automatic version check in `yasb\config.yaml`:

```yaml
update_check: false
```

This applies to all bars and startup methods. It does not prevent manually
updating YASB through the package manager.

## Prevention

Keep `update_check: false` when replacing or updating the configuration.
Do not copy `update_check: true` from upstream examples unless automatic
version checks are wanted.

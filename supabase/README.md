## Push Notification Rollout

This folder scaffolds Empire's APNs-backed notification pipeline.

### Database

Apply the migration in `migrations/20260402_notifications_apns.sql` to create:

- `user_push_tokens`
- `notification_preferences`
- `notification_events`
- triggers for likes, comments, follows, and meet updates
- `queue_meet_reminder_events()` for scheduled meet reminder events

Also apply `migrations/20260404_track_push_tokens_by_installation.sql` so each app install keeps a stable push-token record and stale token rotations do not make delivery look successful on the wrong device.

### Edge Functions

- `send-push`: reads pending `notification_events` and delivers them to APNs
- `queue-meet-reminders`: queues reminder events for upcoming RSVP'd meets

### Required Edge Function Secrets

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APNS_TEAM_ID`
- `APNS_KEY_ID`
- `APNS_PRIVATE_KEY`
- `APNS_BUNDLE_ID`

### Suggested Scheduling

Run these on a schedule in Supabase:

1. `queue-meet-reminders` every 5 minutes
2. `send-push` every 1 minute

You can also invoke `send-push` after deployments or admin-driven meet updates for faster delivery.

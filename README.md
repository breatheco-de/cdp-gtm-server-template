# 4Geeks CDP tag for server-side Google Tag Manager

A server container tag that sends events to the 4Geeks Customer Data Platform (`POST /v1/track`).
It runs on your GTM server, so the token never reaches visitors' browsers.

## Setup

1. In the CDP, open **Agent tokens → Connect an agent → Server-side GTM** and mint a token. It can
   only send events: it can't read profiles or connect as an AI agent. Mint one per website.
2. In your **server** container, open **Templates → Tag Templates → Search Gallery** and add
   **4Geeks CDP**. (Before the gallery listing is live: **New → ⋮ → Import** and pick
   `template.tpl` from this repository.)
3. Add a tag of type **4Geeks CDP**:
   - **CDP endpoint**: the address shown on Agent tokens, ending in `/v1/track`.
   - **Ingest token**: the token from step 1.
   - Trigger: all events. The tag skips Google's background events on its own.
4. In the CDP, click **Add Google and Meta spellings** (Agent tokens or **Nurturing settings →
   Event names**) so GA4 names like `sign_up` and `purchase` count as the CDP's own events.
5. Open GTM **Preview** and load your site. Events show on the CDP **Ingest** page as
   `via gtm_server`, on test profiles while preview is on.

## What the tag sends

| CDP field | Taken from |
|---|---|
| `event` | **Event name override**, or the GA4 `event_name` |
| `anonymousId` | GA4 `client_id` (Google's browser ID) |
| `userId` | **User ID** field, or `user_id` |
| `email` | **Email** field, or `user_data.email_address` (dropped if it isn't a valid address, for example when hashed) |
| `phone` | **Phone** field, or `user_data.phone_number` |
| `eventId` | `event_id` when the site sets one; the CDP stores the same ID from the same source once |
| `properties` | Every other event parameter except `x-…` keys (turn off under Advanced) |
| `isTest` | On while GTM preview is on, or with **Send as test** |

### Visitors the CDP doesn't know yet

With **Send visitors we don't know yet** on (the default), an event with only the browser ID
creates a nameless profile. When an email, phone or user ID later arrives with the same browser
ID, that profile becomes the person's and keeps its history. The CDP deletes nameless profiles
after 60 days with no activity.

With the switch off, such events are only stored when the browser already belongs to someone.

### Renaming events

Leave **Event name override** empty and link GA4 names to the CDP's names under Event names, or
pick a GTM variable (for example a Lookup Table) in the override to rename several events at once.
Names can't start with `$`.

## Keep the browser ID stable

Safari can reset cookies set by JavaScript after 7 days, which gives a returning visitor a new
browser ID. In the server container's GA4 client, turn on **Server managed** cookies (FPID) so the
ID survives longer.

## Releasing a new version

1. Commit the updated `template.tpl`.
2. Add that commit's sha at the top of `versions` in `metadata.yaml` with short `changeNotes`, and
   commit again. The gallery picks up the newest sha listed.

## License

Apache 2.0, see [LICENSE](LICENSE).

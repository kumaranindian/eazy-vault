# Phase 1 Firebase Changes

## Summary: no changes required to `firestore.rules`, `storage.rules`, or `firestore.indexes.json`.

Every Phase 1 feature was checked against the deployed rule/index shape before implementation.
None needed a change. Details per feature:

| Feature | Firestore schema | Firestore rules | Firestore indexes | Storage rules |
|---|---|---|---|---|
| View Attachment fix | No change — reads the existing `attachments` field. | No change. | No change. | No change. |
| Settings/Profile | Writes only `displayName`/`updatedAt` on the existing `users/{uid}` doc. | No change — the existing owner-update rule (`request.resource.data.createdAt == resource.data.createdAt && ...createdBy == ...`) already allows this. | No change. | N/A |
| Category delete | No new fields. The new "in use" guard is a query (`transactions` where `categoryId == X && isDeleted == false`, `limit(1)`), not a schema change. | No change — delete is still a soft-delete `update`. | No change — equality-only query on a single field; Firestore auto-indexes that. | N/A |
| Recurring catch-up on create | No change — reuses the existing `transactions`/`recurringTransactions` write paths unchanged. | No change. | No change. | N/A |
| Budget & bill notifications | No new collection — alert state (enabled flag, dedup keys) lives in `SharedPreferences`, not Firestore. | No change. | No change. | N/A |
| Net worth history | No new collection — reconstructed on read from existing `accounts`/`transactions` via `getAccountHistory`, already an existing query shape. | No change. | No change — same `isDeleted + accountId + date` query pattern account statements already use. | N/A |
| CSV import | No new fields — imported rows become ordinary `transactions` documents via the existing `createTransaction` path. The duplicate-check query (`accountId` + `isDeleted` + `date` range) is already covered by the existing `isDeleted + accountId + date` composite index (CLAUDE.md §5/§22). | No change — created exactly like a manually entered transaction (`createdBy` set, soft-delete only). | No change. | N/A |
| Receipt/photo attachments | Writes to the existing `attachments` field only, via one new `AccountBalanceService.updateAttachments` method (plain document update, no balance fields touched). | No change — the existing transaction `update` rule (`allow update: if isOwner(userId)`) already permits this; rules don't validate individual fields today (per CLAUDE.md §14), so no new rule is needed to scope it further than it already is. | No change. | **No change** — `storage.rules` already had `match /transactions/{userId}/{transactionId}/{fileName}` with owner-only read/write/delete, a 5 MB cap, and image/PDF content-type validation, ready and unused before this phase. |

## New dependency

`csv: ^6.0.0` (pub.dev package, not a Firebase change) — used for parsing arbitrary bank-statement
CSVs during import.

## If rules/indexes ever do need to change in the future

Per `CLAUDE.md` §14/§18: security-rule changes need `firebase deploy --only firestore:rules` (or
`storage`) to take effect, and index changes need `firebase deploy --only firestore:indexes` before
any new combined-filter query will work. Neither deploy was necessary for this phase.

## 1. Backend — Store

- [x] 1.1 Add `deleteArchiveById(id)` public method to `FileLogArchiveStore` in `backend/src/log_archive_store.js` (delegates to existing private `#deleteArchive`; returns `true` if deleted, `false` if not found)

## 2. Backend — Route

- [x] 2.1 Add `DELETE /v1/admin/log-archives/:id` route in `backend/src/routes/admin.js`; look up archive, return 404 if missing, call `deleteArchiveById`, return 204 on success
- [x] 2.2 Document `DELETE /v1/admin/log-archives/:id` in `contracts/api.md` (204 success, 403 forbidden, 404 not_found)

## 3. Backend — Tests

- [x] 3.1 Add unit tests for `deleteArchiveById` in `backend/test/log_archives_api.test.js`: success (204), not-found (404), missing-token (403)
- [x] 3.2 Run `cd backend && npm test` and confirm all tests pass

## 4. Dashboard — Data Layer

- [x] 4.1 Add `deleteLogArchive(id: string)` async function to `expat8-dashboard/src/lib/ops-data.ts` that calls `DELETE /v1/admin/log-archives/:id` with admin credentials and returns `{ error: string | null }`

## 5. Dashboard — Delete Single Archive

- [x] 5.1 Create Server Action `deleteArchiveAction(id)` in `expat8-dashboard/src/app/ops/logs/[id]/actions.ts` that calls `deleteLogArchive`, handles errors, and on success calls `redirect('/ops/logs')`
- [x] 5.2 Add a delete form/button to the detail page `expat8-dashboard/src/app/ops/logs/[id]/page.tsx` that invokes the Server Action and shows an error state if the action returns an error

## 6. Dashboard — Bulk Delete Expired

- [x] 6.1 Create Server Action `deleteExpiredArchivesAction(ids: string[])` in `expat8-dashboard/src/app/ops/logs/actions.ts` that calls `deleteLogArchive` for each id and calls `revalidatePath('/ops/logs')` on completion
- [x] 6.2 Add a "Delete all expired" form/button to the list page `expat8-dashboard/src/app/ops/logs/page.tsx` that passes the IDs of all expired archives to the Server Action; show feedback when none are expired

## 7. Dashboard — Stats Bar

- [x] 7.1 Render the stats bar on the list page using `summarizeLogArchives` (already imported from `ops.js`): show total count, formatted total size (`formatBytes`), active count, expired count; display above the filter form

## 8. Dashboard — User Filter

- [x] 8.1 Add `user` query param handling to `filterLogArchives` in `expat8-dashboard/src/lib/ops.js`: case-insensitive substring match on `source_user_id`
- [x] 8.2 Add User filter `<input name="user">` to the list page filter form and pass `params.user` to `filterLogArchives`

## 9. Dashboard — Build & Lint

- [x] 9.1 Run `cd expat8-dashboard && npm run lint` and fix any lint errors
- [x] 9.2 Run `cd expat8-dashboard && npm run build` and confirm build succeeds with no type errors

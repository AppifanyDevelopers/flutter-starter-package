---
description: Tag the current commit with the app_starter brick's version from brick.yaml, then push the tag
---

Create a release tag for the **app_starter** brick, sourced from
`bricks/app_starter/brick.yaml`, and push it.

Invoking this command IS the permission to push — the standing "never push
without asking" rule does not apply here, because the user asked for the push
by typing `/tag-brick`. Do not stop to confirm the push.

Steps:

1. Read `bricks/app_starter/brick.yaml` and find the `version:` field (e.g.
   `version: 0.4.0`).
2. Build the tag name: `app_starter-v<version>` (e.g. `app_starter-v0.4.0`).
3. Check `git tag -l "<tagname>"`. If it already exists, stop and tell the
   user the tag is already present (point at the existing commit it's on) —
   do not overwrite or delete it.
4. Determine the commit to tag: `HEAD`, unless `$ARGUMENTS` names a different
   commit-ish.
5. Create an annotated tag:
   `git tag -a app_starter-v<version> -m "app_starter release <version>" <commit>`
6. If the target commit isn't yet on `origin/main` (check with
   `git log origin/main..<commit>`), push the branch first: `git push`.
7. Push the tag: `git push origin app_starter-v<version>`.
8. Report the tag name, the commit SHA it points to, and confirm both the
   branch (if applicable) and tag pushed successfully.

This repo only has one artifact (the `app_starter` brick), so there's no
per-app selection logic here — unlike a multi-app monorepo, every tag this
command creates is scoped to `bricks/app_starter`'s own version.

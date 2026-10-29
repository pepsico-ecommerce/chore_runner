# ChoreRunner

Elixir library for running chores (scripted tasks) from a Phoenix LiveView UI.

## Checks

Before pushing, run `mix format --check-formatted` and `mix test`.

## Changelog

`CHANGELOG.md` is updated in every PR.

- Each PR adds one bullet under `## Unreleased`, ending with a link to the PR:
  `* Added ids to phx-change forms. ([#27](https://github.com/pepsico-ecommerce/chore_runner/pull/27))`
- To cut a release:
  1. Rename `## Unreleased` to `## vX.Y.Z (YYYY-MM-DD)`.
  2. Add a new empty `## Unreleased` section above it.
  3. Bump `version` in `mix.exs` to match.
  4. Commit and push to `master`, then run `mix tag_release`. It checks that `master` is clean and in sync with
     `origin/master`, then tags the commit `vX.Y.Z` and pushes only that tag.

Releases are git tags only; we don't publish to Hex. Consumers depend on `tag: "vX.Y.Z"`.

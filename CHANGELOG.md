# Changelog

## Unreleased

* Added optional `validate_inputs/1` cross-field validation for live forms and programmatic chore execution.
* Preserve previously entered URL-persisted values when a form change sends only changed fields.
* Preserve URL-persisted boolean values when LiveView rerenders chore forms.
* Improve file input contrast and display the selected file name above its upload progress.

## v0.7.0 (2026-08-05)

* Added `selectbox` inputs with static or callback-provided Phoenix options.
* Added input defaults for UI and programmatic chore execution.
* Added opt-in URL persistence for non-file form inputs.
* Added persistent chore filtering through the URL.
* Added an expandable instructions panel with `@moduledoc` fallback.
* Scoped UI styles to ChoreRunner and added accessible disabled-button states and input help text.

## v0.2.0 (2022-08-12)

### Breaking Change

* Added "Live Navigation" and dropped support for `live_render/3` based integration

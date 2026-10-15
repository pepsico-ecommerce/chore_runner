# Changelog

## Unreleased

* Added optional `validate_inputs/1` cross-field validation for live forms and programmatic chore execution.
* Preserve text, number, and select values across URL patches, including partial form-change payloads.
* Preserve URL-persisted boolean values when LiveView rerenders chore forms.
* Render string validation messages without inspection quotes.
* Render human-readable messages for built-in input validation errors.
* Improve file input contrast and display the selected file name above its upload progress.
* Added dependent inputs: `:depends_on` hides an input until earlier inputs are valid, one-arity select providers load options from their values, and `:visible?` shows an input conditionally.
* Fixed the `Chore.resolve_inputs/2` spec so Dialyzer accepts the partially built chore struct that `validate_input/1` passes.

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

# Applies a Bedrock maintenance baseline. Standard library only: this runs
# with plain `elixir` before the project's dependencies are fetched.
#
#     elixir scripts/maintenance/apply_baseline.exs apply --baseline baseline.json
#
# See docs/maintenance.md.
Code.require_file("baseline_maintenance.ex", __DIR__)
BaselineMaintenance.main(System.argv())

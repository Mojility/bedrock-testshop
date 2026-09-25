ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Shop.Repo, :manual)

# The maintenance baseline tool runs as a standalone script, outside the
# application, so its tests load it directly.
Code.require_file("../scripts/maintenance/baseline_maintenance.ex", __DIR__)

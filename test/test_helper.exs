# Hard ceiling on how much of the machine the suite can take. `max_cases` alone
# only bounds how many test cases run at once; the BEAM keeps one scheduler per
# core and still spreads the work over all of them. Taking schedulers offline is
# what actually keeps the laptop usable while the suite runs.
#
# The number comes from :test_max_cases in config/test.exs, so raising the limit
# is a single edit there (or the TEST_MAX_CASES env var, which is what CI uses).
# Clamped to the cores the VM actually has: asking for more raises, and CI sets
# TEST_MAX_CASES higher than the runner has cores on purpose, to mean "all of them".
:erlang.system_flag(
  :schedulers_online,
  min(
    Application.get_env(:o_grupo_de_estudos, :test_max_cases, 2),
    :erlang.system_info(:schedulers)
  )
)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(OGrupoDeEstudos.Repo, :manual)

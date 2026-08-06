# Hard ceiling on how much of the machine the suite can take. `max_cases` alone
# only bounds how many test cases run at once; the BEAM keeps one scheduler per
# core and still spreads the work over all of them. Taking schedulers offline is
# what actually keeps the laptop usable while the suite runs.
#
# The number comes from :test_max_cases in config/test.exs, so raising the limit
# is a single edit there (or the TEST_MAX_CASES env var, for a one-off run on a
# free machine). Clamped to the cores the VM actually has, which is what keeps
# an over-large TEST_MAX_CASES from asking for schedulers that do not exist.
:erlang.system_flag(
  :schedulers_online,
  min(
    Application.get_env(:o_grupo_de_estudos, :test_max_cases, 2),
    :erlang.system_info(:schedulers)
  )
)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(OGrupoDeEstudos.Repo, :manual)

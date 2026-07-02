defmodule OGrupoDeEstudos.MixProject do
  use Mix.Project

  def project do
    [
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      app: :o_grupo_de_estudos,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {OGrupoDeEstudos.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:tidewave, "~> 0.6", only: [:dev]},
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      # Hashing de senhas
      {:argon2_elixir, "~> 4.0"},
      # Mailer
      {:swoosh, "~> 1.17"},
      # Adaptador SMTP (necessário em dev para envio real; em prod, trocar por API adapter)
      {:gen_smtp, "~> 1.0"},
      # HTTP client (integração com APIs de IA)
      {:req, "~> 0.6"},
      # Jobs assíncronos (verificação de email, geração de vídeo)
      {:oban, "~> 2.19"},
      # Qualidade de código
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev], runtime: false},
      # Processamento de imagens (crop, resize)
      {:mogrify, "~> 0.9"},
      # Factories de teste
      {:ex_machina, "~> 2.7", only: :test},
      # Seguranca estatica (Sobelow) e auditoria de CVEs em dependencias
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind o_grupo_de_estudos", "esbuild o_grupo_de_estudos"],
      "assets.deploy": [
        "tailwind o_grupo_de_estudos --minify",
        "esbuild o_grupo_de_estudos --minify",
        "phx.digest"
      ],
      # Gate de qualidade. deps.audit ignora o advisory do decimal
      # (GHSA-rhv4-8758-jx7v): preso por ecto `~> 2.0`, sem uso direto.
      # sobelow gateia em High. `-i Config.CSP` e supressao de FALSO-POSITIVO: o
      # CSP existe (Plugs.ContentSecurityPolicy, com nonce por request), mas o
      # sobelow so reconhece CSP em put_secure_browser_headers, nao via plug.
      # Os Traversal Medium/Low restantes sao server-side, com caminhos
      # reconstruidos via Path.basename (falsos positivos).
      lint: [
        "format --check-formatted",
        "deps.audit --ignore-advisory-ids GHSA-rhv4-8758-jx7v",
        "sobelow --exit High -i Config.CSP",
        "credo"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end

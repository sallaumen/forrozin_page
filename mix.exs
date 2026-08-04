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
      # :xmerl is the SAX parser of the R2 adapter (ListObjectsV2).
      #
      # :req_s3 is here for an annoying reason: on partial recompiles Mix sometimes
      # generates the .app WITHOUT it in the applications list, and then dialyzer
      # starts flagging `ReqS3.presign_url/1` as a missing function. It does not
      # affect production (the release builds from a clean _build), but it cost a
      # `touch mix.exs` on every PR. Listing it explicitly makes it deterministic;
      # req_s3 has no supervisor, so starting it is a no-op.
      extra_applications: [:logger, :runtime_tools, :xmerl, :req_s3]
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
      # Password hashing
      {:argon2_elixir, "~> 4.0"},
      # Mailer
      {:swoosh, "~> 1.17"},
      # SMTP adapter (needed in dev for real sending; in prod, swap for an API adapter)
      {:gen_smtp, "~> 1.0"},
      # HTTP client
      {:req, "~> 0.6"},
      {:req_s3, "~> 0.2.3"},
      # Background jobs (email confirmation, video transcode)
      {:oban, "~> 2.19"},
      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev], runtime: false},
      # Image processing (crop, resize)
      {:mogrify, "~> 0.9"},
      # Test factories
      {:ex_machina, "~> 2.7", only: :test},
      # Static security analysis (Sobelow) and dependency CVE audit
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
      # Quality gate. deps.audit ignores the decimal advisory (GHSA-rhv4-8758-jx7v):
      # pinned by ecto `~> 2.0`, with no direct use.
      # sobelow gates on High. `-i Config.CSP` suppresses a FALSE POSITIVE: the CSP
      # does exist (Plugs.ContentSecurityPolicy, with a per-request nonce), but
      # sobelow only recognizes a CSP in put_secure_browser_headers, not through a plug.
      # The remaining Traversal Medium/Low are server-side, with paths rebuilt through
      # Path.basename (false positives). `--skip` honors the inline `# sobelow_skip`,
      # each one justified in the code itself, and it is the narrowest suppression
      # there is: one function, one check.
      lint: [
        "format --check-formatted",
        "deps.audit --ignore-advisory-ids GHSA-rhv4-8758-jx7v",
        "sobelow --exit High -i Config.CSP --skip",
        "credo"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end

# Scripts

Scripts utilitarios para desenvolvimento. **Nunca rodar em producao.**

## Como usar

```bash
# Criar usuario fake com muitos dados
mix run scripts/seed_fake_user.exs

# Preview sem escrever (dry-run)
mix run scripts/seed_fake_user.exs --dry-run

# Limpar todos os usuarios fake
mix run scripts/cleanup_fake_users.exs
```

## Convencoes

- Todo script destrutivo deve chamar `ScriptHelper.guard_not_production!()` no inicio
- Use `ScriptHelper.log/2` para logs estruturados
- Suporte `--dry-run` via `ScriptHelper.dry_run?()`
- Importe `scripts/script_helper.exs` no topo: `Code.require_file("scripts/script_helper.exs")`

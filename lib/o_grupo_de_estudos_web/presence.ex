defmodule OGrupoDeEstudosWeb.Presence do
  @moduledoc """
  Tracks which users are currently online via Phoenix Presence.

  Used to show an "activity pulse" in the desktop top nav — small
  stacked avatars of online users the current user follows.

  ## Disabling

  If this feature causes performance issues or feels like spam,
  it can be disabled by:
  1. Removing the `track_presence/1` call from NotificationSubscriber
  2. Removing the `<.activity_pulse>` from top_nav.ex
  The Presence module itself can stay — it has no side effects when unused.
  """

  use Phoenix.Presence,
    otp_app: :o_grupo_de_estudos,
    pubsub_server: OGrupoDeEstudos.PubSub
end

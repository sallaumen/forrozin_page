defmodule OGrupoDeEstudos.Workshops.Workshop do
  @moduledoc """
  One-off event organized by any user (workshop, open class, roda).

  It has no relation to `TeacherStudentLink`: whoever enrolls in a workshop does
  not become anyone's student. They are different concepts on purpose.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Brazil
  alias OGrupoDeEstudos.Workshops.WorkshopEnrollment

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @slug_random_bytes 4

  schema "workshops" do
    field :slug, :string
    field :title, :string
    field :description, :string
    # The name of the place ("Telhado do Tatá"), not the whole address. Rows written
    # before the split still carry the free line, and the display falls back to it.
    field :location, :string
    field :street, :string
    field :street_number, :string
    field :complement, :string
    field :neighborhood, :string
    field :city, :string
    field :state, :string
    field :postal_code, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :price_cents, :integer
    field :payment_info, :string
    # The WHEN became a choice; `payment_info` kept only the Pix key or an extra
    # instruction. Free text was nothing the system could use.
    field :payment_mode, Ecto.Enum, values: [:on_signup, :at_event]
    field :payment_phone, :string
    field :capacity, :integer
    field :status, Ecto.Enum, values: [:draft, :published, :cancelled], default: :draft
    field :flyer_path, :string
    field :teacher_reminded_at, :utc_datetime
    # Who can see it. Separate from status, which is the life cycle.
    field :visibility, Ecto.Enum, values: [:public, :private], default: :public

    # How long it runs, which is what the form asks. `ends_at` is what queries and
    # the page read, so this only exists to compute it: typing the date twice to
    # say "two hours" is busywork, and the second date is the first one 99% of the
    # time.
    field :duration_minutes, :integer, virtual: true

    belongs_to :organizer, OGrupoDeEstudos.Accounts.User
    # Zero or one program. The context moves it, not the public changeset: joining
    # a program requires administering both sides.
    belongs_to :program, OGrupoDeEstudos.Workshops.WorkshopProgram
    has_many :enrollments, WorkshopEnrollment

    timestamps(type: :utc_datetime_usec)
  end

  @castable [
    :title,
    :description,
    :location,
    :street,
    :street_number,
    :complement,
    :neighborhood,
    :city,
    :state,
    :postal_code,
    :starts_at,
    :ends_at,
    :price_cents,
    :payment_info,
    :payment_mode,
    :payment_phone,
    :capacity,
    :visibility,
    :organizer_id,
    :duration_minutes
  ]

  def changeset(workshop, attrs) do
    workshop
    |> cast(attrs, @castable)
    |> update_change(:title, &trim/1)
    |> update_change(:description, &trim/1)
    |> update_change(:location, &trim/1)
    |> trim_address()
    |> update_change(:state, &String.upcase(trim(&1)))
    |> validate_state()
    |> update_change(:payment_info, &trim/1)
    |> update_change(:payment_phone, &trim/1)
    |> validate_length(:payment_phone, max: 40)
    |> validate_required([:title, :description, :starts_at, :organizer_id])
    |> validate_length(:title, max: 140)
    |> validate_length(:description, max: 20_000)
    |> validate_length(:location, max: 200)
    |> validate_length(:street, max: 200)
    |> validate_length(:street_number, max: 20)
    |> validate_length(:complement, max: 80)
    |> validate_length(:neighborhood, max: 80)
    |> validate_length(:city, max: 80)
    |> validate_length(:postal_code, max: 20)
    |> validate_length(:payment_info, max: 200)
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
    |> validate_number(:capacity, greater_than: 0)
    |> validate_number(:duration_minutes, greater_than: 0)
    |> put_end_from_duration()
    |> validate_end_after_start()
    |> put_slug()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:organizer_id)
  end

  @address_fields [:street, :street_number, :complement, :neighborhood, :city, :postal_code]

  defp trim_address(changeset) do
    Enum.reduce(@address_fields, changeset, &update_change(&2, &1, fn v -> trim(v) end))
  end

  # Optional, so blank passes. Anything else has to be a real state, or the address
  # says "XX" and nobody notices until someone tries to get there.
  defp validate_state(changeset) do
    case get_change(changeset, :state) do
      nil ->
        changeset

      "" ->
        changeset

      state ->
        if Brazil.state?(state), do: changeset, else: add_error(changeset, :state, "não existe")
    end
  end

  @doc """
  The place and the city, which is what a card has room for.

  Falls back to whatever `location` holds when nothing structured was filled: rows
  written before the split keep the whole address in that one field.
  """
  @spec place_line(t()) :: String.t() | nil
  def place_line(%__MODULE__{} = workshop) do
    [present(workshop.location), city_state(workshop)]
    |> compact_join(" · ")
  end

  @doc """
  Street, number, complement, neighborhood, city and postal code, in reading order.

  Returns nil when only the place name is known, so the page can stay quiet instead
  of showing an address made of separators.
  """
  @spec address_line(t()) :: String.t() | nil
  def address_line(%__MODULE__{} = workshop) do
    [
      compact_join(
        [present(workshop.street), present(workshop.street_number), present(workshop.complement)],
        ", "
      ),
      present(workshop.neighborhood),
      city_state(workshop),
      present(workshop.postal_code)
    ]
    |> compact_join(" · ")
  end

  defp city_state(%__MODULE__{city: nil}), do: nil
  defp city_state(%__MODULE__{city: ""}), do: nil

  defp city_state(%__MODULE__{city: city, state: state}),
    do: compact_join([city, present(state)], ", ")

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value), do: value

  defp compact_join(parts, separator) do
    case parts |> Enum.reject(&is_nil/1) |> Enum.join(separator) do
      "" -> nil
      joined -> joined
    end
  end

  @doc "Stores or removes the flyer. The path comes from the storage, never from the user."
  def flyer_changeset(workshop, flyer_path) do
    change(workshop, flyer_path: flyer_path)
  end

  @doc "Muda o estado do workshop (publicar, cancelar, voltar a rascunho)."
  def status_changeset(workshop, status) when status in [:draft, :published, :cancelled] do
    change(workshop, status: status)
  end

  @doc "true when the workshop only opens for whoever was invited."
  @spec private?(t()) :: boolean()
  def private?(%__MODULE__{visibility: :private}), do: true
  def private?(%__MODULE__{}), do: false

  @doc "true when the capacity was reached. With no capacity, it never fills."
  @spec full?(t(), non_neg_integer()) :: boolean()
  def full?(%__MODULE__{capacity: nil}, _enrolled_count), do: false
  def full?(%__MODULE__{capacity: capacity}, enrolled_count), do: enrolled_count >= capacity

  @doc "true when it is free (no price set, or zero)."
  @spec free?(t()) :: boolean()
  def free?(%__MODULE__{price_cents: nil}), do: true
  def free?(%__MODULE__{price_cents: 0}), do: true
  def free?(%__MODULE__{}), do: false

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)

  # The duration wins over any `ends_at` that arrives with it: it is what the form
  # asked, so honouring the other field would silently contradict what was typed.
  # A duration that failed to cast leaves the error alone instead of computing on
  # garbage.
  defp put_end_from_duration(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp put_end_from_duration(changeset) do
    starts_at = get_field(changeset, :starts_at)

    # `get_field` and not `get_change`: re-sending the same duration while moving
    # the start is not a change to the duration, and the end would stay behind.
    case {starts_at, get_field(changeset, :duration_minutes)} do
      {%DateTime{}, minutes} when is_integer(minutes) ->
        put_change(changeset, :ends_at, DateTime.add(starts_at, minutes, :minute))

      _no_duration ->
        changeset
    end
  end

  defp validate_end_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(ends_at, starts_at) != :gt do
      add_error(changeset, :ends_at, "precisa ser depois do início")
    else
      changeset
    end
  end

  # Readable slug from the title plus a short suffix: the link goes to a WhatsApp
  # group, so it has to say what it is about without being guessable enough for
  # someone to scan other people's workshops.
  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_field(changeset, :title)} do
      {nil, title} when is_binary(title) -> put_change(changeset, :slug, build_slug(title))
      _ -> changeset
    end
  end

  defp build_slug(title) do
    base =
      title
      |> String.normalize(:nfd)
      |> String.replace(~r/[^A-Za-z0-9\s-]/u, "")
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/, "-")
      |> String.slice(0, 60)
      |> String.trim("-")

    prefix = if base == "", do: "workshop", else: base
    "#{prefix}-#{random_suffix()}"
  end

  defp random_suffix do
    @slug_random_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "")
    |> String.slice(0, 6)
  end

  @doc """
  WhatsApp link to send the receipt, or `nil`.

  Sending the receipt stops being copy the number, open the app and write which
  workshop it is about: the name already goes in the message.
  """
  @spec receipt_link(t()) :: String.t() | nil
  def receipt_link(%__MODULE__{payment_phone: phone} = workshop) when is_binary(phone) do
    phone |> digits_only() |> with_country_code() |> build_link(workshop)
  end

  def receipt_link(%__MODULE__{}), do: nil

  defp digits_only(phone), do: String.replace(phone, ~r/\D/, "")

  # A Brazilian number without country code has 10 or 11 digits (area code plus
  # number). With it, 12 or 13. Anything else does not become a link: better not
  # to offer one than to offer a link that opens a chat with nobody.
  defp with_country_code(digits) when byte_size(digits) in [10, 11], do: "55" <> digits
  defp with_country_code("55" <> _ = digits) when byte_size(digits) in [12, 13], do: digits
  defp with_country_code(_too_short_or_odd), do: nil

  defp build_link(nil, _workshop), do: nil

  defp build_link(number, %__MODULE__{title: title}) do
    text = URI.encode("Oi! Segue o comprovante do workshop #{title}.")
    "https://wa.me/#{number}?text=#{text}"
  end
end

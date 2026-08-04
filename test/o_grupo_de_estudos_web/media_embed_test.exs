defmodule OGrupoDeEstudosWeb.MediaEmbedTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.MediaEmbed

  describe "resolve/1 with a YouTube video" do
    test "watch?v=ID vira embed wide" do
      assert %{kind: :embed, embed_url: url, label: "YouTube", shape: :wide} =
               MediaEmbed.resolve("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

      assert url == "https://www.youtube.com/embed/dQw4w9WgXcQ"
    end

    test "youtu.be/ID vira embed wide" do
      assert %{kind: :embed, embed_url: "https://www.youtube.com/embed/abc123", shape: :wide} =
               MediaEmbed.resolve("https://youtu.be/abc123")
    end

    test "watch URL with extra params keeps only the id" do
      assert %{embed_url: "https://www.youtube.com/embed/0tFTHcLiwlg"} =
               MediaEmbed.resolve(
                 "https://www.youtube.com/watch?v=0tFTHcLiwlg&list=PL4g9caBcjee5&t=10"
               )
    end
  end

  describe "resolve/1 with YouTube Shorts" do
    test "shorts URL becomes a tall embed with its own label" do
      assert %{
               kind: :embed,
               embed_url: "https://www.youtube.com/embed/kriNyQzfOGI",
               label: "YouTube Shorts",
               shape: :tall
             } = MediaEmbed.resolve("https://www.youtube.com/shorts/kriNyQzfOGI")
    end

    test "shorts URL with a query keeps only the id" do
      assert %{embed_url: "https://www.youtube.com/embed/h3LB_JcMqAY", shape: :tall} =
               MediaEmbed.resolve("https://youtube.com/shorts/h3LB_JcMqAY?si=xyz")
    end
  end

  describe "resolve/1 with Instagram" do
    test "post /p/CODE vira embed portrait" do
      assert %{
               kind: :embed,
               embed_url: "https://www.instagram.com/p/C0o200AtOQ5/embed",
               label: "Instagram",
               shape: :portrait
             } = MediaEmbed.resolve("https://www.instagram.com/p/C0o200AtOQ5/")
    end

    test "reel /reel/CODE vira embed portrait" do
      assert %{embed_url: "https://www.instagram.com/reel/DTGVKpAjfWr/embed", shape: :portrait} =
               MediaEmbed.resolve("https://www.instagram.com/reel/DTGVKpAjfWr/")
    end

    test "instagram profile without a post falls back to external but keeps the label" do
      assert %{kind: :external, label: "Instagram", embed_url: nil} =
               MediaEmbed.resolve("https://www.instagram.com/forro_footwork/")
    end
  end

  describe "resolve/1 with external URLs and edge cases" do
    test "unsupported link becomes external with the host as label" do
      assert %{kind: :external, embed_url: nil, label: "vimeo.com"} =
               MediaEmbed.resolve("https://vimeo.com/123456")
    end

    test "watch sem v vira external" do
      assert %{kind: :external} = MediaEmbed.resolve("https://www.youtube.com/watch")
    end

    test "youtu.be vazio vira external" do
      assert %{kind: :external} = MediaEmbed.resolve("https://youtu.be/")
    end

    test "nil vira external" do
      assert %{kind: :external} = MediaEmbed.resolve(nil)
    end
  end
end

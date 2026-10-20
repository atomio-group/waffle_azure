defmodule WaffleAzureTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @connection_string "AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;DefaultEndpointsProtocol=http;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1"
  @container "waffleazuretest"

  defmodule Definition do
    def storage_dir(_version, _file_and_scope), do: "uploads"
  end

  setup_all do
    Application.put_env(:azurex, Azurex.Blob.Config,
      default_container: @container,
      storage_account_connection_string: @connection_string
    )

    case Azurex.Blob.Container.create(@container) do
      {:ok, _} -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  @tag :tmp_dir
  test "concurrent uploads to the same path all succeed", %{tmp_dir: tmp_dir} do
    contents = :crypto.strong_rand_bytes(20 * 1_024 * 1_024)
    path = Path.join(tmp_dir, "same.pdf")
    File.write!(path, contents)
    file = %Waffle.File{path: path, file_name: "same.pdf"}

    results =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn -> Waffle.Storage.Azure.put(Definition, :original, {file, nil}) end)
      end)
      |> Task.await_many(60_000)

    assert results == [{:ok, "same.pdf"}, {:ok, "same.pdf"}]
    assert Azurex.Blob.get_blob("uploads/same.pdf") == {:ok, contents}
  end
end

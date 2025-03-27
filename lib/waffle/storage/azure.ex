defmodule Waffle.Storage.Azure do
  @default_expiry_time 60 * 5

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})

    full_store_path =
      Path.join(destination_dir, file.file_name) |> String.replace(~r/\s+/, "_") |> String.trim()

    do_put(file, full_store_path)
  end

  def url(definition, version, file_and_scope, options \\ []) do
    path = get_full_path(definition, version, file_and_scope)
    container = Azurex.Blob.Config.default_container()

    case Keyword.get(options, :signed, false) do
      false -> Azurex.Blob.get_url(container, path)
      true -> build_signed_url(container, path, options)
    end
  end

  def delete(definition, version, file_and_scope) do
    path = get_full_path(definition, version, file_and_scope)
    Azurex.Blob.delete_blob(path)
  end

  defp build_signed_url(container, path, options) do
    # Previous waffle argument was expire_in instead of expires_in
    # check for expires_in, if not present, use expire_at.
    options = put_in(options[:expiry], Keyword.get(options, :expires_in, options[:expire_in]))
    # fallback to default, if neither is present.
    options =
      put_in(options[:expiry], {:second, options[:expiry] || @default_expiry_time})

    options = put_in(options[:resource_type], :blob)

    Azurex.Blob.SharedAccessSignature.sas_url(container, path, options)
  end

  defp get_full_path(definition, version, file_and_scope) do
    destination_dir = definition.storage_dir(version, file_and_scope)

    file_name =
      Waffle.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)

    Path.join(destination_dir, file_name) |> String.replace(~r/\s+/, "_") |> String.trim()
  end

  defp do_put(file, store_path, params \\ [])

  defp do_put(file = %Waffle.File{binary: file_binary}, store_path, params)
       when is_binary(file_binary) do
    Azurex.Blob.put_blob(store_path, file_binary, MIME.from_path(file.file_name), params)

    {:ok, file.file_name}
  end

  defp do_put(file, store_path, params) do
    file_stream = File.stream!(file.path)

    Azurex.Blob.put_blob(
      store_path,
      {:stream, file_stream},
      "application/octet-stream",
      Azurex.Blob.Config.default_container(),
      params
    )

    {:ok, file.file_name}
  end
end

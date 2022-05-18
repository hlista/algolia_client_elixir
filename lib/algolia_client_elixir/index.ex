defmodule AlgoliaClientElixir.Index do
  alias AlgoliaClientElixir.Response
  alias AlgoliaClientElixir.Uri

  @type name :: String.t()

  @wait_task_default_time_before_retry 100

  def list_indexes(request_options \\ %{}) do
    Response.get(Uri.indexes_uri(), :read, request_options)
  end

  def delete(index_name, request_options \\ %{}) do
    index_name
    |> Uri.index_uri()
    |> Response.delete(:write, request_options)
  end

  def add_object(index_name, object, object_id \\ nil, request_options \\ %{})

  def add_object(index_name, object, nil, request_options) do
    index_name
    |> Uri.index_uri()
    |> Response.post(Jason.encode!(object), :write, request_options)
  end

  def add_object(index_name, object, object_id, request_options) do
    index_name
    |> Uri.object_uri(object_id)
    |> Response.put(Jason.encode!(object), :write, request_options)
  end

  def add_objects(index_name, objects, request_options \\ %{}) do
    batch(index_name, build_batch("addObject", objects, false), request_options)
  end

  def get_object(index_name, object_id, attributes_to_retrieve \\ nil, request_options \\ %{})

  def get_object(index_name, object_id, nil, request_options) do
    index_name
    |> Uri.object_uri(object_id)
    |> Response.get(:read, request_options)
  end

  def get_object(index_name, object_id, attributes_to_retrieve, request_options) do
    attributes_to_retrieve = Enum.join(attributes_to_retrieve, ",")
    index_name
    |> Uri.object_uri(object_id, %{ attributes: attributes_to_retrieve })
    |> Response.get(:read, request_options)
  end

  def get_objects(index_name, object_ids, attributes_to_retrieve \\ nil, request_options \\ %{})

  def get_objects(index_name, object_ids, nil, request_options) do
    requests = Enum.map(object_ids, fn object_id -> 
      %{
        "indexName" => index_name,
        "objectID" => object_id
      }
    end)
    Response.post(Uri.objects_uri, Jason.encode!(%{ requests: requests }), :read, request_options)["results"]
  end

  def get_objects(index_name, object_ids, attributes_to_retrieve, request_options) do
    attributes_to_retrieve = Enum.join(attributes_to_retrieve, ",")
    requests = Enum.map(object_ids, fn object_id -> 
      %{
        "indexName" => index_name,
        "objectID" => object_id,
        "attributesToRetrieve" => attributes_to_retrieve
      }
    end)
    Response.post(Uri.objects_uri, Jason.encode!(%{ requests: requests }), :read, request_options)["results"]
  end

  def save_object(index_name, object, request_options \\ %{}) do
    index_name
    |> Uri.object_uri(object["objectID"])
    |> Response.put(Jason.encode!(object), :write, request_options)
  end

  def save_objects(index_name, objects, request_options \\ %{}) do
    batch(index_name, build_batch("updateObject", objects, true), request_options)
  end

  def delete_object(index_name, object_id, request_options \\ %{}) do
    index_name
    |> Uri.object_uri(object_id)
    |> Response.delete(:write, request_options)
  end

  def delete_objects(index_name, object_ids, request_options \\ %{}) do
    batch(index_name, build_batch("deleteObject", Enum.map(object_ids, fn object_id -> %{ "objectID" => object_id } end), false), request_options)
  end

  def partial_update_object(index_name, object, create_if_not_exits \\ true, request_options \\ %{}) do
    index_name
    |> Uri.partial_object_uri(object["objectID"], create_if_not_exits)
    |> Response.post(Jason.encode!(object), :write, request_options)
  end

  def copy_index(src_index, dst_index, scope \\ nil, request_options \\ %{})

  def copy_index(src_index, dst_index, nil, request_options) do
    request = %{ "operation" => "copy", "destination" => dst_index }
    src_index
    |> Uri.index_operation_uri()
    |> Response.post(Jason.encode!(request), :write, request_options)
  end

  def copy_index(src_index, dst_index, scope, request_options) do
    request = %{ "operation" => "copy", "destination" => dst_index, "scope" => scope }
    src_index
    |> Uri.index_operation_uri()
    |> Response.post(Jason.encode!(request), :write, request_options)
  end

  def copy_index!(src_index, dst_index, scope \\ nil, request_options \\ %{}) do
    with {:ok, response} <- copy_index(src_index, dst_index, scope, request_options) do
      wait_task(dst_index, response["taskID"], @wait_task_default_time_before_retry, request_options)
      {:ok, response}
    end
  end

  def move_index(src_index, dst_index, request_options \\ %{}) do
    request = %{ "operation" => "move", "destination" => dst_index }
    src_index
    |> Uri.index_operation_uri()
    |> Response.post(Jason.encode!(request), :write, request_options)
  end

  def move_index!(src_index, dst_index, request_options \\ {}) do
    with {:ok, response} <- move_index(src_index, dst_index, request_options) do
      wait_task(dst_index, response["taskID"], @wait_task_default_time_before_retry, request_options)
      {:ok, response}
    end
  end

  def replace_all_objects(index_name, objects, request_options \\ %{})

  def replace_all_objects(index_name, %Stream{} = objects, request_options) do
    tmp_index = index_name <> "_tmp_" <> Integer.to_string(:rand.uniform(10000000))

    scope = ["settings", "synonyms", "rules"]
    copy_index!(index_name, tmp_index, scope, request_options)

    Stream.chunk_every(objects, 1000)
    |> Enum.reduce([], fn batch, responses ->
      with {:ok, response} <- add_objects(tmp_index, batch, request_options) do
        [response | responses]
      else
        _ ->
          responses
      end
    end)
    |> Enum.each(fn response ->
      wait_task(tmp_index, response["taskID"], @wait_task_default_time_before_retry, request_options)
    end)

    move_index!(tmp_index, index_name, request_options)
  end

  def replace_all_objects(index_name, objects, request_options) do
    tmp_index = index_name <> "_tmp_" <> Integer.to_string(:rand.uniform(10000000))

    scope = ["settings", "synonyms", "rules"]
    copy_index!(index_name, tmp_index, scope, request_options)

    Enum.chunk_every(objects, 1000)
    |> Enum.reduce([], fn batch, responses ->
      with {:ok, response} <- add_objects(tmp_index, batch, request_options) do
        [response | responses]
      else
        _ ->
          responses
      end
    end)
    |> Enum.each(fn response ->
      wait_task(tmp_index, response["taskID"], @wait_task_default_time_before_retry, request_options)
    end)

    move_index!(tmp_index, index_name, request_options)
  end

  def clear(index_name, request_options \\ %{}) do
    index_name
    |> Uri.clear_uri()
    |> Response.post(Jason.encode!(%{}), :write, request_options)
  end

  def clear!(index_name, request_options \\ %{}) do
    with {:ok, response} <- clear(index_name, request_options) do
      wait_task(index_name, response["taskID"], @wait_task_default_time_before_retry, request_options)
      {:ok, response}
    end
  end

  def set_settings(index_name, new_settings, options \\ %{}, request_options \\ %{}) do
    index_name
    |> Uri.settings_uri(options)
    |> Response.put(Jason.encode!(new_settings), :write, request_options)
  end

  def batch(index_name, request, request_options \\ %{}) do
    index_name
    |> Uri.batch_uri()
    |> Response.post(Jason.encode!(request), :batch, request_options)
  end

  def get_task_status(index_name, task_id, request_options \\ %{}) do
    index_name
    |> Uri.task_uri(task_id)
    |> Response.get(:read, request_options)
  end

  def wait_task(
        index_name,
        task_id,
        time_before_retry \\ @wait_task_default_time_before_retry,
        request_options \\ %{}
      ) do
    with {:ok, response} <- get_task_status(index_name, task_id, request_options) do
      case response["status"] do
        "published" ->
          {:ok, task_id}

        _ ->
          :timer.sleep(time_before_retry)
          wait_task(index_name, task_id, time_before_retry, request_options)
      end
    end
  end

  def build_batch(action, objects, false) do
    %{
      requests:
        Enum.map(objects, fn object -> 
          %{
            "action" => action,
            "body" => object,
          }
        end)
    }
  end

  def build_batch(action, objects, true) do
    %{
      requests:
        Enum.map(objects, fn object -> 
          %{
            "action" => action,
            "body" => object,
            "objectID" => object["objectID"]
          }
        end)
    }
  end
end
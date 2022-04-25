defmodule Algolia.Index do
  defstruct [:name]
  alias Algolia.Client
  alias Algolia.Protocol

  @type name :: String.t()
  @type t :: %Algolia.Index{name: name}

  @wait_task_default_time_before_retry 100

  def init_index(name) when is_bitstring(name) and byte_size(name) > 0 do
    %Algolia.Index{name: name}
  end

  def list_indexes(request_options \\ %{}) do
    Client.get(Protocol.indexes_uri(), :read, request_options)
  end

  def delete(%Algolia.Index{name: name}, request_options \\ %{}) do
    name
    |> Protocol.index_uri()
    |> Client.delete(:write, request_options)
  end

  def add_object(index, object, object_id \\ nil, request_options \\ %{})

  def add_object(%Algolia.Index{name: name}, object, nil, request_options) do
    name
    |> Protocol.index_uri()
    |> Client.post(object, :write, request_options)
  end

  def add_object(%Algolia.Index{name: name}, object, object_id, request_options) do
    name
    |> Protocol.object_uri(object_id)
    |> Client.put(object, :write, request_options)
  end

  def add_objects(%Algolia.Index{name: _} = index, objects, request_options \\ %{}) do
    batch(index, build_batch("addObject", objects, false), request_options)
  end

  def get_object(index, object_id, attributes_to_retrieve \\ nil, request_options \\ %{})

  def get_object(%Algolia.Index{name: name}, object_id, nil, request_options) do
    name
    |> Protocol.object_uri(object_id)
    |> Client.get(:read, request_options)
  end

  def get_object(%Algolia.Index{name: name}, object_id, attributes_to_retrieve, request_options) do
    attributes_to_retrieve = Enum.join(attributes_to_retrieve, ",")
    name
    |> Protocol.object_uri(object_id, %{ attributes: attributes_to_retrieve })
    |> Client.get(:read, request_options)
  end

  def get_objects(index, object_ids, attributes_to_retrieve \\ nil, request_options \\ %{})

  def get_objects(%Algolia.Index{name: name}, object_ids, nil, request_options) do
    requests = Enum.map(object_ids, fn object_id -> 
      %{
        "indexName" => name,
        "objectID" => object_id
      }
    end)
    Client.post(Protocol.objects_uri, %{ requests: requests }, :read, request_options)["results"]
  end

  def get_objects(%Algolia.Index{name: name}, object_ids, attributes_to_retrieve, request_options) do
    attributes_to_retrieve = Enum.join(attributes_to_retrieve, ",")
    requests = Enum.map(object_ids, fn object_id -> 
      %{
        "indexName" => name,
        "objectID" => object_id,
        "attributesToRetrieve" => attributes_to_retrieve
      }
    end)
    Client.post(Protocol.objects_uri, %{ requests: requests }, :read, request_options)["results"]
  end

  def save_object(%Algolia.Index{name: name}, object, request_options \\ %{}) do
    name
    |> Protocol.object_uri(object["objectID"])
    |> Client.put(object, :write, request_options)
  end

  def save_objects(%Algolia.Index{name: _} = index, objects, request_options \\ %{}) do
    batch(index, build_batch("updateObject", objects, true), request_options)
  end

  def delete_object(%Algolia.Index{name: name}, object_id, request_options \\ %{}) do
    name
    |> Protocol.object_uri(object_id)
    |> Client.delete(:write, request_options)
  end

  def delete_objects(%Algolia.Index{name: _} = index, object_ids, request_options \\ %{}) do
    batch(index, build_batch("deleteObject", Enum.map(object_ids, fn object_id -> %{ "objectID" => object_id } end), false), request_options)
  end

  def partial_update_object(%Algolia.Index{name: name}, object, create_if_not_exits \\ true, request_options \\ %{}) do
    name
    |> Protocol.partial_object_uri(object["objectID"], create_if_not_exits)
    |> Client.post(object, :write, request_options)
  end

  def copy_index(src_index, dst_index, scope \\ nil, request_options \\ %{})

  def copy_index(%Algolia.Index{name: src_index}, %Algolia.Index{name: dst_index}, nil, request_options) do
    request = %{ "operation" => "copy", "destination" => dst_index }
    src_index
    |> Protocol.index_operation_uri()
    |> Client.post(request, :write, request_options)
  end

  def copy_index(%Algolia.Index{name: src_index}, %Algolia.Index{name: dst_index}, scope, request_options) do
    request = %{ "operation" => "copy", "destination" => dst_index, "scope" => scope }
    src_index
    |> Protocol.index_operation_uri()
    |> Client.post(request, :write, request_options)
  end

  def copy_index!(%Algolia.Index{name: _} = src_index, %Algolia.Index{name: dst_index_name} = dst_index, scope \\ nil, request_options \\ %{}) do
    with {:ok, response} <- copy_index(src_index, dst_index, scope, request_options) do
      Client.wait_task(dst_index_name, response["taskID"], @wait_task_default_time_before_retry, request_options)
      {:ok, response}
    end
  end

  def move_index(%Algolia.Index{name: src_index}, %Algolia.Index{name: dst_index}, request_options \\ %{}) do
    request = %{ "operation" => "move", "destination" => dst_index }
    src_index
    |> Protocol.index_operation_uri()
    |> Client.post(request, :write, request_options)
  end

  def move_index!(%Algolia.Index{name: _} = src_index, %Algolia.Index{name: dst_index_name} = dst_index, request_options \\ {}) do
    with {:ok, response} <- move_index(src_index, dst_index, request_options) do
      Client.wait_task(dst_index_name, response["taskID"], @wait_task_default_time_before_retry, request_options)
      {:ok, response}
    end
  end

  def replace_all_objects(index, objects, request_options \\ %{})

  def replace_all_objects(%Algolia.Index{name: name} = index, %Stream{} = objects, request_options) do
    tmp_index_name = name <> "_tmp_" <> Integer.to_string(:rand.uniform(10000000))
    tmp_index = init_index(tmp_index_name)

    scope = ["settings", "synonyms", "rules"]
    copy_index!(index, tmp_index, scope, request_options)

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
      Client.wait_task(tmp_index_name, response["taskID"], @wait_task_default_time_before_retry, request_options)
    end)

    move_index!(tmp_index, index, request_options)
  end

  def replace_all_objects(%Algolia.Index{name: name} = index, objects, request_options) do
    tmp_index_name = name <> "_tmp_" <> Integer.to_string(:rand.uniform(10000000))
    tmp_index = init_index(tmp_index_name)

    scope = ["settings", "synonyms", "rules"]
    copy_index!(index, tmp_index, scope, request_options)

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
      Client.wait_task(tmp_index_name, response["taskID"], @wait_task_default_time_before_retry, request_options)
    end)

    move_index!(tmp_index, index, request_options)
  end

  def clear(%Algolia.Index{name: name}, request_options \\ %{}) do
    name
    |> Protocol.clear_uri()
    |> Client.post(%{}, :write, request_options)
  end

  def clear!(%Algolia.Index{name: name} = index, request_options \\ %{}) do
    with {:ok, response} <- clear(index, request_options) do
      Client.wait_task(name, response["taskID"], @wait_task_default_time_before_retry, request_options)
      {:ok, response}
    end
  end

  def set_settings(%Algolia.Index{name: name}, new_settings, options \\ %{}, request_options \\ %{}) do
    name
    |> Protocol.settings_uri(options)
    |> Client.put(new_settings, :write, request_options)
  end

  def batch(%Algolia.Index{name: name}, request, request_options \\ %{}) do
    name
    |> Protocol.batch_uri()
    |> Client.post(request, :batch, request_options)
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
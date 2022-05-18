defmodule AlgoliaClientElixir.Uri do

  @version 1

  def indexes_uri() do
    "/#{@version}/indexes"
  end

  def multiple_queries_uri(strategy \\ "none") do
    "/#{@version}/indexes/*/queries?strategy=#{strategy}"
  end

  def objects_uri() do
    "/#{@version}/indexes/*/objects"
  end

  # Construct a uri referencing a given Algolia index
  def index_uri(index) do
    "/#{@version}/indexes/#{URI.encode(index)}"
  end

  def batch_uri(index \\ nil)

  def batch_uri(nil) do
    "/#{@version}/indexes/*/batch"
  end

  def batch_uri(index) do
    "#{index_uri(index)}/batch"
  end

  def index_operation_uri(index) do
    "#{index_uri(index)}/operation"
  end

  def task_uri(index, task_id) do
    "#{index_uri(index)}/task/#{task_id}"
  end

  def object_uri(index, object_id, params \\ %{})

  def object_uri(index, object_id, params) when map_size(params) == 0 do
    "#{index_uri(index)}/#{URI.encode(object_id)}"
  end

  def object_uri(index, object_id, params) do
    "#{index_uri(index)}/#{URI.encode(object_id)}?#{to_query(params)}"
  end

  def search_uri(index, query, params \\ %{})

  def search_uri(index, query, params) when map_size(params) == 0 do
    "#{index_uri(index)}?query=#{URI.encode(query)}"
  end

  def search_uri(index, query, params) do
    "#{index_uri(index)}?query=#{URI.encode(query)}&#{to_query(params)}"
  end

  def search_post_uri(index) do
    "#{index_uri(index)}/query"
  end

  def browse_uri(index, params \\ %{})

  def browse_uri(index, params) when map_size(params) == 0 do
    "#{index_uri(index)}/browse"
  end

  def browse_uri(index, params) do
    "#{index_uri(index)}/browse?#{to_query(params)}"
  end

  def search_facet_uri(index, facet) do
    "#{index_uri(index)}/facets/#{URI.encode(facet)}/query"
  end

  def partial_object_uri(index, object_id, create_if_not_exits \\ true)

  def partial_object_uri(index, object_id, true) do
    "#{index_uri(index)}/#{URI.encode(object_id)}/partial"
  end

  def partial_object_uri(index, object_id, false) do
    "#{index_uri(index)}/#{URI.encode(object_id)}/partial?createIfNotExists=false"
  end

  def settings_uri(index, params \\ %{})

  def settings_uri(index, params) when map_size(params) == 0 do
    "#{index_uri(index)}/settings"
  end

  def settings_uri(index, params) do
    "#{index_uri(index)}/settings?#{to_query(params)}"
  end

  def clear_uri(index) do
    "#{index_uri(index)}/clear"
  end

  def logs(offset, size, type) do
    "/#{@version}/logs?offset=#{offset}&length=#{size}&type=#{type}"
  end

  def keys_uri() do
    "/#{@version}/keys"
  end

  def key_uri(key) do
    "/#{@version}/keys/#{key}"
  end

  def restore_key_uri(key) do
    "/#{@version}/keys/#{key}/restore"
  end

  def index_key_uri(index, key) do
    "#{index_uri(index)}/keys/#{key}"
  end

  def index_keys_uri(index) do
    "#{index_uri(index)}/keys"
  end

  def to_query(params) do
    params
    |> Enum.map(fn {key, value} -> 
      Enum.join([key, value], "=")
    end)
    |> Enum.join("&")
    |> URI.encode()
  end

  def synonyms_uri(index) do
    "#{index_uri(index)}/synonyms"
  end

  def synonym_uri(index, object_id) do
    "#{synonyms_uri(index)}/#{URI.encode(object_id)}"
  end

  def search_synonyms_uri(index) do
    "#{synonyms_uri(index)}/search"
  end

  def clear_synonyms_uri(index) do
    "#{synonyms_uri(index)}/clear"
  end

  def batch_synonyms_uri(index) do
    "#{synonyms_uri(index)}/batch"
  end

  def rules_uri(index) do
    "#{index_uri(index)}/rules"
  end

  def rule_uri(index, object_id) do
    "#{rules_uri(index)}/#{URI.encode(object_id)}"
  end

  def search_rules_uri(index) do
    "#{rules_uri(index)}/search"
  end

  def clear_rules_uri(index) do
    "#{rules_uri(index)}/clear"
  end

  def batch_rules_uri(index) do
    "#{rules_uri(index)}/batch"
  end

  def delete_by_uri(index) do
    "#{index_uri(index)}/deleteByQuery"
  end

  def personalization_strategy_uri() do
    "/1/recommendation/personalization/strategy"
  end

  def clusters_uri() do
    "/#{@version}/clusters"
  end

  def cluster_mapping_uri() do
    "/#{@version}/clusters/mapping"
  end

  def cluster_mapping_uri(user_id) do
    "/#{@version}/clusters/mapping/#{URI.encode(user_id)}"
  end

  def list_ids_uri(page, hits_per_page) do
    cluster_mapping_uri() <> "?page=#{URI.encode(page)}&hitsPerPage=#{URI.encode(hits_per_page)}"
  end

  def cluster_top_user_uri() do
    "/#{@version}/clusters/mapping/top"
  end

  def search_user_id_uri() do
    "/#{@version}/clusters/mapping/search"
  end

  def ab_tests_uri() do
    "/2/abtests"
  end

  def ab_tests_uri(ab_test) do
    "/2/abtests/#{ab_test}"
  end

  def ab_tests_stop_uri(ab_test) do
    "/2/abtests/#{ab_test}/stop"
  end
end
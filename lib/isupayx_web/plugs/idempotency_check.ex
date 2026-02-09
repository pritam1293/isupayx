defmodule IsupayxWeb.Plugs.IdempotencyCheck do
  @moduledoc """
  Plug to handle idempotency via Idempotency-Key header.
  
  TC9: Idempotency rules:
  - Same key + same body → return cached response (200 OK)
  - Same key + different body → return conflict error (409)
  - No key → allow request to proceed
  
  Stores idempotency cache in ETS table (in-memory for now).
  Production would use Redis or database.
  """

  import Plug.Conn
  alias IsupayxWeb.ErrorResponse

  @table_name :idempotency_cache

  def init(opts) do
    # Create ETS table if it doesn't exist
    unless :ets.whereis(@table_name) != :undefined do
      :ets.new(@table_name, [:named_table, :public, :set])
    end
    opts
  end

  # Helper to clear all cache entries (for testing)
  def clear_cache do
    case :ets.whereis(@table_name) do
      :undefined -> {:error, :table_not_found}
      _ref -> 
        :ets.delete_all_objects(@table_name)
        {:ok, :cleared}
    end
  end

  def call(conn, _opts) do
    case get_req_header(conn, "idempotency-key") do
      [] ->
        # No idempotency key provided - allow request
        conn
      
      [idempotency_key | _] ->
        handle_idempotency(conn, idempotency_key)
    end
  end

  defp handle_idempotency(conn, idempotency_key) do
    merchant_id = conn.assigns[:current_merchant].id
    cache_key = {merchant_id, idempotency_key}
    
    # Get the already-parsed params from conn
    # Phoenix's Plug.Parsers has already converted JSON to params
    params = conn.params
    
    # Create hash from params for comparison
    params_json = Jason.encode!(params)
    body_hash = :crypto.hash(:sha256, params_json) |> Base.encode16()
    
    case :ets.lookup(@table_name, cache_key) do
      [] ->
        # First time seeing this idempotency key
        # Store it for future requests
        :ets.insert(@table_name, {cache_key, body_hash, nil})
        
        # Assign idempotency info to conn
        conn
        |> assign(:idempotency_key, idempotency_key)
        |> assign(:idempotency_body_hash, body_hash)
      
      [{^cache_key, stored_body_hash, cached_response}] ->
        if body_hash == stored_body_hash do
          # Same key + same body → return cached response
          if cached_response do
            send_cached_response(conn, cached_response)
          else
            # Response not cached yet (race condition or first request still processing)
            # Allow request but mark as duplicate
            conn
            |> assign(:idempotency_key, idempotency_key)
            |> assign(:idempotency_body_hash, body_hash)
            |> assign(:idempotency_duplicate, true)
          end
        else
          # Same key + different body → conflict
          send_conflict(conn, idempotency_key)
        end
    end
  end

  defp send_cached_response(conn, cached_response) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(cached_response))
    |> halt()
  end

  defp send_conflict(conn, idempotency_key) do
    {status, body} = ErrorResponse.to_response(
      "idempotency",
      "IDEMPOTENCY_CONFLICT",
      "Request body differs from original request with same Idempotency-Key",
      %{idempotency_key: idempotency_key}
    )
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
    |> halt()
  end

  @doc """
  Caches the response for an idempotency key.
  Call this from the controller after successfully creating a transaction.
  """
  def cache_response(merchant_id, idempotency_key, body_hash, response) do
    cache_key = {merchant_id, idempotency_key}
    :ets.insert(@table_name, {cache_key, body_hash, response})
  end
  
  @doc """
  Gets the cached response for an idempotency key.
  Returns {:ok, response} if found, {:error, :not_found} otherwise.
  """
  def get_cached_response(merchant_id, idempotency_key) do
    cache_key = {merchant_id, idempotency_key}
    
    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, _body_hash, response}] -> {:ok, response}
      _ -> {:error, :not_found}
    end
  end
end

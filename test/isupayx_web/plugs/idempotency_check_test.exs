defmodule IsupayxWeb.Plugs.IdempotencyCheckTest do
  use IsupayxWeb.ConnCase, async: false
  alias IsupayxWeb.Plugs.IdempotencyCheck

  setup do
    # Clear and ensure ETS table exists
    try do
      :ets.delete(:idempotency_cache)
    catch
      :error, :badarg -> :ok
    end
    
    :ets.new(:idempotency_cache, [:set, :public, :named_table])
    :ok
  end

  describe "idempotency check" do
    test "allows request without idempotency key", %{conn: conn} do
      conn = IdempotencyCheck.call(conn, [])
      refute conn.halted
    end

    test "stores body hash for first request with idempotency key", %{conn: conn} do
      params = %{"amount" => 1000}
      
      conn = conn
        |> Map.put(:params, params)
        |> put_req_header("idempotency-key", "test_key_001")
        |> assign(:current_merchant, %{id: "merchant_001"})
        |> IdempotencyCheck.call([])

      refute conn.halted
      assert conn.assigns[:idempotency_key] == "test_key_001"
      assert conn.assigns[:idempotency_body_hash] != nil
    end

    test "returns 409 for same key with different body", %{conn: conn} do
      merchant = %{id: "merchant_conflict"}
      idem_key = "conflict_key"

      # First request
      conn1 = conn
        |> put_req_header("idempotency-key", idem_key)
        |> assign(:current_merchant, merchant)
        |> Map.put(:params, %{"amount" => 1000})

      conn1 = IdempotencyCheck.call(conn1, [])
      refute conn1.halted

      # Cache a response
      IdempotencyCheck.cache_response(
        merchant.id,
        idem_key,
        conn1.assigns[:idempotency_body_hash],
        %{transaction_id: "txn_001"}
      )

      # Second request with different body
      conn2 = build_conn()
        |> put_req_header("idempotency-key", idem_key)
        |> assign(:current_merchant, merchant)
        |> Map.put(:params, %{"amount" => 2000})  # Different amount

      conn2 = IdempotencyCheck.call(conn2, [])
      
      assert conn2.halted
      assert conn2.status == 409
      response = Jason.decode!(conn2.resp_body)
      assert response["error"]["code"] == "IDEMPOTENCY_CONFLICT"
    end
  end
end

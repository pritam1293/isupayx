defmodule IsupayxWeb.TransactionController do
  use IsupayxWeb, :controller

  alias Isupayx.Repo
  alias Isupayx.Transactions.Transaction
  alias Isupayx.Validation.{SchemaValidator, BusinessRuleValidator, ComplianceValidator, RiskValidator}
  alias IsupayxWeb.{ErrorResponse, Plugs.IdempotencyCheck}

  @doc """
  POST /api/v1/transactions
  
  Creates a new transaction after passing through all 5 validation layers:
  1. Schema validation (400)
  2. Entity validation (403) - handled by AuthenticateMerchant plug
  3. Business rules (422)
  4. Compliance checks (flags only, doesn't fail)
  5. Risk/velocity (429)
  """
  def create(conn, params) do
    merchant = conn.assigns.current_merchant
    idempotency_key = conn.assigns[:idempotency_key]
    
    # Check if we have a cached response for this idempotency key
    cached_response = if idempotency_key do
      case IdempotencyCheck.get_cached_response(merchant.id, idempotency_key) do
        {:ok, response} when not is_nil(response) -> response
        _ -> nil
      end
    else
      nil
    end
    
    if cached_response do
      # Return cached response with 200 OK
      conn
      |> put_status(:ok)
      |> json(cached_response)
    else
      # No cached response, proceed with validation and creation
      process_new_transaction(conn, params, merchant, idempotency_key)
    end
  end
  
  defp process_new_transaction(conn, params, merchant, idempotency_key) do
    # Convert string keys to atoms for validation
    params = atomize_keys(params)
    
    # Run validation pipeline
    with {:ok, validated_params} <- SchemaValidator.validate(params),
         :ok <- BusinessRuleValidator.validate(validated_params, merchant),
         {:ok, compliance_flags} <- ComplianceValidator.validate(validated_params),
         :ok <- RiskValidator.validate(merchant),
         {:ok, transaction} <- create_transaction(validated_params, merchant, compliance_flags, idempotency_key) do
      
      # Success response
      response = build_success_response(transaction, compliance_flags)
      
      # Cache response for idempotency
      if idempotency_key do
        body_hash = conn.assigns[:idempotency_body_hash]
        IdempotencyCheck.cache_response(merchant.id, idempotency_key, body_hash, response)
      end
      
      conn
      |> put_status(:created)
      |> json(response)
    else
      {:error, {layer, code, message, details}} ->
        {status, body} = ErrorResponse.to_response(layer, code, message, details)
        
        conn
        |> put_status(status)
        |> json(body)
      
      # Handle database constraint errors (duplicate idempotency key)
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "DUPLICATE_TRANSACTION",
            message: "Transaction with this idempotency key already exists",
            details: %{errors: translate_changeset_errors(changeset)}
          }
        })
    end
  end

  defp create_transaction(params, merchant, compliance_flags, idempotency_key) do
    # Parse amount
    amount = case params[:amount] do
      amount when is_number(amount) -> Decimal.new(to_string(amount))
      amount when is_binary(amount) ->
        case Decimal.parse(amount) do
          {decimal, _} -> decimal
          :error -> Decimal.new("0")
        end
    end
    
    # Build transaction attrs
    attrs = %{
      merchant_id: merchant.id,
      amount: amount,
      currency: params[:currency] || "INR",
      payment_method: params[:payment_method],
      reference_id: params[:reference_id],
      customer_email: params[:customer][:email],
      customer_phone: params[:customer][:phone],
      idempotency_key: idempotency_key,
      compliance_flags: compliance_flags,
      status: "processing",  # TC1: Created in "processing" state
      metadata: params[:metadata] || %{}
    }
    
    # Create transaction
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  defp build_success_response(transaction, compliance_flags) do
    response = %{
      success: true,
      transaction_id: transaction.id,
      status: transaction.status,
      amount: Decimal.to_string(transaction.amount, :normal),
      currency: transaction.currency,
      payment_method: transaction.payment_method,
      reference_id: transaction.reference_id,
      created_at: transaction.inserted_at
    }
    
    # TC8: Add compliance flags to metadata if present
    if length(compliance_flags) > 0 do
      Map.put(response, :metadata, %{compliance_flags: compliance_flags})
    else
      response
    end
  end

  defp translate_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # Helper to convert string keys to atoms recursively
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {atomize_key(k), atomize_keys(v)}
    end)
  end
  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value

  defp atomize_key(key) when is_binary(key), do: String.to_atom(key)
  defp atomize_key(key) when is_atom(key), do: key
end

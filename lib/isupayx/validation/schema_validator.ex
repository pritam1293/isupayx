defmodule Isupayx.Validation.SchemaValidator do
  @moduledoc """
  Layer 1: Schema Validation
  
  Validates:
  - Required fields are present
  - Data types are correct
  - Formats are valid (email, phone)
  - Amount > 0
  
  Returns {:ok, validated_params} or {:error, {layer, code, message, details}}
  """

  @required_fields [:amount, :currency, :payment_method, :reference_id, :customer]
  @customer_required_fields [:email, :phone]

  def validate(params) do
    with :ok <- validate_required_fields(params),
         :ok <- validate_customer_fields(params),
         :ok <- validate_amount(params),
         :ok <- validate_email(params),
         :ok <- validate_phone(params) do
      {:ok, params}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_required_fields(params) do
    missing = Enum.filter(@required_fields, fn field ->
      not Map.has_key?(params, field) or is_nil(params[field])
    end)

    case missing do
      [] -> :ok
      [field | _] ->
        {:error, {"schema", "SCHEMA_MISSING_FIELD", 
          "Required field '#{field}' is missing", 
          %{field: field}}}
    end
  end

  defp validate_customer_fields(params) do
    customer = params[:customer] || %{}
    
    missing = Enum.filter(@customer_required_fields, fn field ->
      not Map.has_key?(customer, field) or is_nil(customer[field])
    end)

    case missing do
      [] -> :ok
      [field | _] ->
        {:error, {"schema", "SCHEMA_MISSING_FIELD",
          "Required customer field '#{field}' is missing",
          %{field: "customer.#{field}"}}}
    end
  end

  defp validate_amount(params) do
    amount = params[:amount]
    
    cond do
      is_nil(amount) ->
        :ok  # Already caught by required fields check
      
      not is_number(amount) and not is_binary(amount) ->
        {:error, {"schema", "SCHEMA_INVALID_TYPE",
          "Amount must be a number",
          %{field: :amount, value: amount}}}
      
      is_number(amount) and amount <= 0 ->
        {:error, {"schema", "SCHEMA_INVALID_AMOUNT",
          "Amount must be greater than 0",
          %{field: :amount, value: amount}}}
      
      is_binary(amount) ->
        case Decimal.parse(amount) do
          {decimal, _} ->
            if Decimal.compare(decimal, Decimal.new("0")) in [:lt, :eq] do
              {:error, {"schema", "SCHEMA_INVALID_AMOUNT",
                "Amount must be greater than 0",
                %{field: :amount, value: amount}}}
            else
              :ok
            end
          :error ->
            {:error, {"schema", "SCHEMA_INVALID_TYPE",
              "Amount must be a valid number",
              %{field: :amount, value: amount}}}
        end
      
      true -> :ok
    end
  end

  defp validate_email(params) do
    email = get_in(params, [:customer, :email])
    
    if email && !String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
      {:error, {"schema", "SCHEMA_INVALID_FORMAT",
        "Invalid email format",
        %{field: "customer.email", value: email}}}
    else
      :ok
    end
  end

  defp validate_phone(params) do
    phone = get_in(params, [:customer, :phone])
    
    # Phone must be in E.164 format: +[country code][number]
    if phone && !String.match?(phone, ~r/^\+[1-9]\d{1,14}$/) do
      {:error, {"schema", "SCHEMA_INVALID_FORMAT",
        "Phone must be in E.164 format (e.g., +919876543210)",
        %{field: "customer.phone", value: phone}}}
    else
      :ok
    end
  end
end

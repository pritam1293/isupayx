defmodule Isupayx.Validation.BusinessRuleValidator do
  @moduledoc """
  Layer 3: Business Rule Validation
  
  Validates:
  - Payment method min/max amounts
  - Per-transaction limits
  - KYC tier limits (if applicable)
  
  Returns :ok or {:error, {layer, code, message, details}}
  """

  alias Isupayx.Repo
  alias Isupayx.Payments.PaymentMethod

  def validate(params, _merchant) do
    payment_method_code = params[:payment_method]
    amount = parse_amount(params[:amount])
    
    with {:ok, payment_method} <- find_payment_method(payment_method_code),
         :ok <- validate_payment_method_active(payment_method),
         :ok <- validate_amount_limits(payment_method, amount) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_amount(amount) when is_number(amount), do: Decimal.new(to_string(amount))
  defp parse_amount(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end

  defp find_payment_method(code) do
    case Repo.get_by(PaymentMethod, code: code) do
      nil ->
        {:error, {"business_rule", "RULE_INVALID_PAYMENT_METHOD",
          "Payment method '#{code}' is not supported",
          %{payment_method: code}}}
      
      payment_method ->
        {:ok, payment_method}
    end
  end

  defp validate_payment_method_active(payment_method) do
    if payment_method.is_active do
      :ok
    else
      {:error, {"business_rule", "RULE_PAYMENT_METHOD_INACTIVE",
        "Payment method '#{payment_method.code}' is currently unavailable",
        %{payment_method: payment_method.code}}}
    end
  end

  defp validate_amount_limits(payment_method, amount) do
    cond do
      payment_method.min_amount && Decimal.compare(amount, payment_method.min_amount) == :lt ->
        # TC7: Amount below minimum
        {:error, {"business_rule", "RULE_AMOUNT_BELOW_MIN",
          "Amount ₹#{amount} is below minimum ₹#{payment_method.min_amount} for #{payment_method.name}",
          %{
            amount: Decimal.to_string(amount),
            min_amount: Decimal.to_string(payment_method.min_amount),
            payment_method: payment_method.code
          }}}
      
      payment_method.max_amount && Decimal.compare(amount, payment_method.max_amount) == :gt ->
        # TC6: Amount exceeds maximum
        {:error, {"business_rule", "RULE_AMOUNT_ABOVE_MAX",
          "Amount ₹#{amount} exceeds maximum ₹#{payment_method.max_amount} for #{payment_method.name}",
          %{
            amount: Decimal.to_string(amount),
            max_amount: Decimal.to_string(payment_method.max_amount),
            payment_method: payment_method.code
          }}}
      
      true ->
        :ok
    end
  end
end

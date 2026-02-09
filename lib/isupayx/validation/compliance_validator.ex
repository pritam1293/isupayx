defmodule Isupayx.Validation.ComplianceValidator do
  @moduledoc """
  Layer 4: Compliance Checks
  
  Validates:
  - Large transaction reporting (amount > ₹200,000)
  
  NOTE: Compliance checks DO NOT fail the transaction.
  They add flags to the transaction metadata.
  
  Returns {:ok, compliance_flags} where compliance_flags is a list of strings
  """

  @large_transaction_threshold Decimal.new("200000")

  def validate(params) do
    amount = parse_amount(params[:amount])
    flags = []
    
    flags = if Decimal.compare(amount, @large_transaction_threshold) == :gt do
      # TC8: Large transactions get flagged but still succeed
      ["AMOUNT_REPORTING" | flags]
    else
      flags
    end
    
    {:ok, flags}
  end

  defp parse_amount(amount) when is_number(amount), do: Decimal.new(to_string(amount))
  defp parse_amount(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end
end

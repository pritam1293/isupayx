defmodule Isupayx.Validation.RiskValidator do
  @moduledoc """
  Layer 5: Risk/Velocity Checks
  
  Validates:
  - Velocity control: More than 10 transactions in 5 minutes = reject
  
  Returns :ok or {:error, {layer, code, message, details}}
  """

  alias Isupayx.Repo
  alias Isupayx.Transactions.Transaction
  import Ecto.Query

  @velocity_limit 10
  @velocity_window_minutes 5

  def validate(merchant) do
    five_minutes_ago = DateTime.utc_now() |> DateTime.add(-@velocity_window_minutes * 60, :second)
    
    count = Repo.one(
      from t in Transaction,
      where: t.merchant_id == ^merchant.id,
      where: t.inserted_at >= ^five_minutes_ago,
      select: count(t.id)
    )
    
    if count >= @velocity_limit do
      {:error, {"risk", "RISK_VELOCITY_EXCEEDED",
        "Transaction rate limit exceeded. Maximum #{@velocity_limit} transactions per #{@velocity_window_minutes} minutes.",
        %{
          current_count: count,
          limit: @velocity_limit,
          window_minutes: @velocity_window_minutes
        }}}
    else
      :ok
    end
  end
end

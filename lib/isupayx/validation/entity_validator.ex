defmodule Isupayx.Validation.EntityValidator do
  @moduledoc """
  Layer 2: Entity Validation
  
  Validates:
  - Merchant exists
  - Merchant is active (onboarding_status = "activated")
  - KYC status is valid ("approved" OR "verified" for backward compatibility)
  
  Returns {:ok, merchant} or {:error, {layer, code, message, details}}
  """

  alias Isupayx.Repo
  alias Isupayx.Merchants.Merchant

  def validate(api_key) do
    with {:ok, merchant} <- find_merchant(api_key),
         :ok <- validate_onboarding_status(merchant),
         :ok <- validate_kyc_status(merchant) do
      {:ok, merchant}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_merchant(api_key) do
    case Repo.get_by(Merchant, api_key: api_key) do
      nil ->
        {:error, {"entity", "ENTITY_MERCHANT_NOT_FOUND",
          "Merchant not found for provided API key",
          %{}}}
      
      merchant ->
        {:ok, merchant}
    end
  end

  defp validate_onboarding_status(merchant) do
    # TC4: Only "activated" merchants can process transactions
    if merchant.onboarding_status == "activated" do
      :ok
    else
      {:error, {"entity", "ENTITY_MERCHANT_INACTIVE",
        "Merchant is not activated. Current status: #{merchant.onboarding_status}",
        %{onboarding_status: merchant.onboarding_status}}}
    end
  end

  defp validate_kyc_status(merchant) do
    # TC5: Both "approved" (new) and "verified" (legacy) are valid
    if merchant.kyc_status in ["approved", "verified"] do
      :ok
    else
      {:error, {"entity", "ENTITY_MERCHANT_KYC_INVALID",
        "Merchant KYC is not approved. Current status: #{merchant.kyc_status}",
        %{kyc_status: merchant.kyc_status}}}
    end
  end
end

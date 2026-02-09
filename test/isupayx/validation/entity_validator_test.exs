defmodule Isupayx.Validation.EntityValidatorTest do
  use Isupayx.DataCase, async: true
  alias Isupayx.Validation.EntityValidator
  alias Isupayx.Merchants.Merchant

  describe "validate/1" do
    setup do
      # Create active merchant with approved KYC
      merchant = insert!(:merchant, 
        api_key: "test_key_active_#{:rand.uniform(100000)}",
        email: "active_#{:rand.uniform(100000)}@example.com",
        onboarding_status: "activated",
        kyc_status: "approved"
      )

      # Create inactive merchant
      inactive = insert!(:merchant,
        api_key: "test_key_inactive_#{:rand.uniform(100000)}",
        email: "inactive_#{:rand.uniform(100000)}@example.com",
        onboarding_status: "review",
        kyc_status: "approved"
      )

      # Create merchant with invalid KYC
      invalid_kyc = insert!(:merchant,
        api_key: "test_key_pending_kyc_#{:rand.uniform(100000)}",
        email: "pending_#{:rand.uniform(100000)}@example.com",
        onboarding_status: "activated",
        kyc_status: "pending"
      )

      %{merchant: merchant, inactive: inactive, invalid_kyc: invalid_kyc}
    end

    test "validates active merchant with valid KYC", %{merchant: merchant} do
      assert {:ok, validated_merchant} = EntityValidator.validate(merchant.api_key)
      assert validated_merchant.id == merchant.id
      assert validated_merchant.onboarding_status == "activated"
      assert validated_merchant.kyc_status == "approved"
    end

    test "returns error for non-existent merchant" do
      assert {:error, {"entity", "ENTITY_MERCHANT_NOT_FOUND", message, _}} = 
        EntityValidator.validate("invalid_key")
      assert message =~ "not found"
    end

    test "returns error for inactive merchant", %{inactive: inactive} do
      assert {:error, {"entity", "ENTITY_MERCHANT_INACTIVE", message, _}} = 
        EntityValidator.validate(inactive.api_key)
      assert message =~ "not activated"
    end

    test "returns error for invalid KYC status", %{invalid_kyc: merchant} do
      assert {:error, {"entity", "ENTITY_MERCHANT_KYC_INVALID", message, _}} = 
        EntityValidator.validate(merchant.api_key)
      assert message =~ "KYC"
    end

    test "accepts legacy 'verified' KYC status" do
      merchant = insert!(:merchant,
        api_key: "test_key_legacy_#{:rand.uniform(100000)}",
        email: "legacy_#{:rand.uniform(100000)}@example.com",
        onboarding_status: "activated",
        kyc_status: "verified"  # Legacy status
      )

      assert {:ok, validated} = EntityValidator.validate(merchant.api_key)
      assert validated.kyc_status == "verified"
    end
  end

  # Helper function to insert test data
  defp insert!(_schema, attrs) do
    default_attrs = %{
      business_name: "Test Business",
      email: "test_#{:rand.uniform(100000)}@example.com",
      api_key: "test_key_#{:rand.uniform(100000)}",
      onboarding_status: "activated",
      kyc_status: "approved"
    }
    
    %Merchant{}
    |> Merchant.changeset(Map.merge(default_attrs, Enum.into(attrs, %{})))
    |> Repo.insert!()
  end
end

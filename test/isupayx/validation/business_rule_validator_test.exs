defmodule Isupayx.Validation.BusinessRuleValidatorTest do
  use Isupayx.DataCase, async: true
  alias Isupayx.Validation.BusinessRuleValidator
  alias Isupayx.Merchants.Merchant
  alias Isupayx.Payments.PaymentMethod

  setup do
    merchant = insert_merchant!()
    
    # Create payment methods with limits
    upi = insert_payment_method!("upi", "UPI", 1, 200_000)
    credit_card = insert_payment_method!("credit_card", "Credit Card", 100, 500_000)
    
    # Associate payment methods with merchant
    associate_payment_method!(merchant, upi)
    associate_payment_method!(merchant, credit_card)

    %{merchant: merchant, upi: upi, credit_card: credit_card}
  end

  describe "validate/2" do
    test "allows valid UPI transaction within limits", %{merchant: merchant} do
      params = %{amount: 1500, payment_method: "upi"}
      assert :ok = BusinessRuleValidator.validate(params, merchant)
    end

    test "rejects UPI transaction above maximum", %{merchant: merchant} do
      params = %{amount: 250000, payment_method: "upi"}
      
      assert {:error, {"business_rule", "RULE_AMOUNT_ABOVE_MAX", message, details}} =
        BusinessRuleValidator.validate(params, merchant)
      assert message =~ "maximum"
      assert details.max_amount == "200000"
    end

    test "rejects credit card transaction below minimum", %{merchant: merchant} do
      params = %{amount: 50, payment_method: "credit_card"}
      
      assert {:error, {"business_rule", "RULE_AMOUNT_BELOW_MIN", message, details}} =
        BusinessRuleValidator.validate(params, merchant)
      assert message =~ "minimum"
      assert details.min_amount == "100"
    end

    test "rejects payment method not associated with merchant", %{merchant: merchant} do
      params = %{amount: 1000, payment_method: "netbanking"}
      
      assert {:error, {"business_rule", "RULE_INVALID_PAYMENT_METHOD", message, _}} =
        BusinessRuleValidator.validate(params, merchant)
      assert message =~ "not supported"
    end

    test "rejects invalid payment method" do
      merchant = insert_merchant!("unique_#{:rand.uniform(100000)}@example.com")
      params = %{amount: 1000, payment_method: "invalid_method"}
      
      assert {:error, {"business_rule", "RULE_INVALID_PAYMENT_METHOD", message, _}} =
        BusinessRuleValidator.validate(params, merchant)
      assert message =~ "not supported"
    end
  end

  defp insert_merchant!(email \\ nil) do
    %Merchant{}
    |> Merchant.changeset(%{
      business_name: "Test Business",
      email: email || "test_#{:rand.uniform(100000)}@example.com",
      api_key: "test_key_#{:rand.uniform(100000)}",
      onboarding_status: "activated",
      kyc_status: "approved"
    })
    |> Repo.insert!()
  end

  defp insert_payment_method!(code, name, min, max) do
    %PaymentMethod{}
    |> PaymentMethod.changeset(%{
      code: code,
      name: name,
      min_amount: Decimal.new(min),
      max_amount: Decimal.new(max),
      is_active: true
    })
    |> Repo.insert!()
  end

  defp associate_payment_method!(merchant, payment_method) do
    Repo.insert!(%Isupayx.Merchants.MerchantPaymentMethod{
      merchant_id: merchant.id,
      payment_method_id: payment_method.id
    })
  end
end

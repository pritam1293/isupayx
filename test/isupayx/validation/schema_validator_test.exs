defmodule Isupayx.Validation.SchemaValidatorTest do
  use ExUnit.Case, async: true
  alias Isupayx.Validation.SchemaValidator

  describe "validate/1" do
    test "validates valid transaction parameters" do
      params = %{
        amount: 1500,
        currency: "INR",
        payment_method: "upi",
        reference_id: "ORDER-001",
        customer: %{
          email: "test@example.com",
          phone: "+919876543210"
        }
      }

      assert {:ok, validated} = SchemaValidator.validate(params)
      assert validated.amount == 1500
      assert validated.currency == "INR"
    end

    test "returns error for missing required field" do
      params = %{
        currency: "INR",
        payment_method: "upi",
        reference_id: "ORDER-001",
        customer: %{email: "test@example.com", phone: "+919876543210"}
      }

      assert {:error, {"schema", "SCHEMA_MISSING_FIELD", message, details}} = 
        SchemaValidator.validate(params)
      assert message =~ "Required"
      assert details.field == :amount
    end

    test "returns error for negative amount" do
      params = %{
        amount: -500,
        currency: "INR",
        payment_method: "upi",
        reference_id: "ORDER-001",
        customer: %{email: "test@example.com", phone: "+919876543210"}
      }

      assert {:error, {"schema", "SCHEMA_INVALID_AMOUNT", message, _}} = 
        SchemaValidator.validate(params)
      assert message =~ "greater than 0"
    end

    test "returns error for invalid phone format" do
      params = %{
        amount: 1500,
        currency: "INR",
        payment_method: "upi",
        reference_id: "ORDER-001",
        customer: %{email: "test@example.com", phone: "123456"}
      }

      assert {:error, {"schema", "SCHEMA_INVALID_FORMAT", message, _}} = 
        SchemaValidator.validate(params)
      assert message =~ "E.164"
    end

    test "returns error for invalid email format" do
      params = %{
        amount: 1500,
        currency: "INR",
        payment_method: "upi",
        reference_id: "ORDER-001",
        customer: %{email: "invalid-email", phone: "+919876543210"}
      }

      assert {:error, {"schema", "SCHEMA_INVALID_FORMAT", message, _}} = 
        SchemaValidator.validate(params)
      assert message =~ "email"
    end
  end
end

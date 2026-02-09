defmodule Isupayx.Payments.PaymentMethod do
  @moduledoc """
  Payment method schema with transaction limits and configuration.
  
  ## Payment Methods
  Based on test cases:
  - UPI: max ₹200,000 (TC6)
  - Credit Card: min ₹100.00 (TC7)
  - Debit Card: limits TBD
  - Net Banking: appears to have high limits (TC8 uses ₹250,000)
  
  This schema allows per-method configuration of min/max amounts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "payment_methods" do
    field :code, :string  # upi, credit_card, debit_card, netbanking
    field :name, :string  # Display name: "UPI", "Credit Card", etc.
    field :description, :string
    
    # Transaction limits in INR (can be nil for no limit)
    field :min_amount, :decimal
    field :max_amount, :decimal
    
    # Per-transaction limit (different from max_amount)
    field :per_transaction_limit, :decimal
    
    # Daily limits
    field :daily_limit, :decimal
    field :daily_transaction_count_limit, :integer
    
    # Configuration flags
    field :is_active, :boolean, default: true
    field :requires_verification, :boolean, default: false
    
    # Processing settings
    field :processing_fee_percentage, :decimal, default: Decimal.new("0")
    field :processing_fee_fixed, :decimal, default: Decimal.new("0")
    
    # Metadata for gateway-specific config
    field :config, :map, default: %{}
    
    timestamps(type: :utc_datetime)
    
    # Associations
    many_to_many :merchants, Isupayx.Merchants.Merchant,
      join_through: Isupayx.Merchants.MerchantPaymentMethod
  end

  @doc """
  Changeset for payment method creation and updates.
  """
  def changeset(payment_method, attrs) do
    payment_method
    |> cast(attrs, [
      :code,
      :name,
      :description,
      :min_amount,
      :max_amount,
      :per_transaction_limit,
      :daily_limit,
      :daily_transaction_count_limit,
      :is_active,
      :requires_verification,
      :processing_fee_percentage,
      :processing_fee_fixed,
      :config
    ])
    |> validate_required([:code, :name])
    |> validate_inclusion(:code, ~w(upi credit_card debit_card netbanking))
    |> validate_number(:min_amount, greater_than_or_equal_to: 0)
    |> validate_number(:max_amount, greater_than_or_equal_to: 0)
    |> validate_limits()
    |> unique_constraint(:code)
  end

  # Validates that max_amount >= min_amount if both are set
  defp validate_limits(changeset) do
    min = get_field(changeset, :min_amount)
    max = get_field(changeset, :max_amount)

    if min && max && Decimal.compare(min, max) == :gt do
      add_error(changeset, :max_amount, "must be greater than or equal to min_amount")
    else
      changeset
    end
  end

  @doc """
  Checks if an amount is within the payment method's limits.
  
  Returns {:ok, payment_method} or {:error, reason}
  """
  def validate_amount(%__MODULE__{} = payment_method, amount) do
    cond do
      not payment_method.is_active ->
        {:error, :payment_method_inactive}

      payment_method.min_amount && Decimal.compare(amount, payment_method.min_amount) == :lt ->
        {:error, :amount_below_minimum}

      payment_method.max_amount && Decimal.compare(amount, payment_method.max_amount) == :gt ->
        {:error, :amount_above_maximum}

      true ->
        {:ok, payment_method}
    end
  end
end

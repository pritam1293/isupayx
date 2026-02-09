defmodule Isupayx.Merchants.MerchantPaymentMethod do
  @moduledoc """
  Join table between merchants and payment methods.
  
  This is NOT a simple foreign key table - it stores additional attributes
  as mentioned in the requirements:
  - Merchant-specific overrides for min/max amounts
  - Custom processing fees per merchant
  - Activation status per merchant-method combination
  
  ## Example Use Case
  A merchant might have:
  - UPI enabled with custom ₹50,000 limit (lower than system default)
  - Credit cards disabled
  - Net banking with custom processing fees
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "merchant_payment_methods" do
    # Foreign keys
    belongs_to :merchant, Isupayx.Merchants.Merchant
    belongs_to :payment_method, Isupayx.Payments.PaymentMethod
    
    # Merchant-specific configuration (overrides payment method defaults)
    field :is_enabled, :boolean, default: true
    
    # Custom limits for this merchant (overrides payment_method limits if set)
    field :custom_min_amount, :decimal
    field :custom_max_amount, :decimal
    field :custom_daily_limit, :decimal
    
    # Custom fees for this merchant
    field :custom_fee_percentage, :decimal
    field :custom_fee_fixed, :decimal
    
    # Settlement configuration
    field :settlement_days, :integer, default: 1
    field :auto_settlement, :boolean, default: true
    
    # Risk and compliance
    field :requires_manual_review, :boolean, default: false
    field :max_transaction_count_per_day, :integer
    
    # Metadata for merchant-specific settings
    field :config, :map, default: %{}
    
    # Activation tracking
    field :enabled_at, :utc_datetime
    field :disabled_at, :utc_datetime
    field :enabled_by, :string  # Admin user who enabled/disabled
    
    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for merchant payment method association.
  """
  def changeset(merchant_payment_method, attrs) do
    merchant_payment_method
    |> cast(attrs, [
      :merchant_id,
      :payment_method_id,
      :is_enabled,
      :custom_min_amount,
      :custom_max_amount,
      :custom_daily_limit,
      :custom_fee_percentage,
      :custom_fee_fixed,
      :settlement_days,
      :auto_settlement,
      :requires_manual_review,
      :max_transaction_count_per_day,
      :config,
      :enabled_at,
      :disabled_at,
      :enabled_by
    ])
    |> validate_required([:merchant_id, :payment_method_id])
    |> validate_number(:custom_min_amount, greater_than_or_equal_to: 0)
    |> validate_number(:custom_max_amount, greater_than_or_equal_to: 0)
    |> validate_limits()
    |> unique_constraint([:merchant_id, :payment_method_id], 
         name: :merchant_payment_methods_merchant_id_payment_method_id_index)
    |> foreign_key_constraint(:merchant_id)
    |> foreign_key_constraint(:payment_method_id)
  end

  # Validates that custom_max_amount >= custom_min_amount if both are set
  defp validate_limits(changeset) do
    min = get_field(changeset, :custom_min_amount)
    max = get_field(changeset, :custom_max_amount)

    if min && max && Decimal.compare(min, max) == :gt do
      add_error(changeset, :custom_max_amount, "must be greater than or equal to custom_min_amount")
    else
      changeset
    end
  end

  @doc """
  Gets the effective min amount (custom override or payment method default).
  """
  def effective_min_amount(%__MODULE__{} = mpm, payment_method) do
    mpm.custom_min_amount || payment_method.min_amount
  end

  @doc """
  Gets the effective max amount (custom override or payment method default).
  """
  def effective_max_amount(%__MODULE__{} = mpm, payment_method) do
    mpm.custom_max_amount || payment_method.max_amount
  end
end

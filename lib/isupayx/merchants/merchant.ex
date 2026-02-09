defmodule Isupayx.Merchants.Merchant do
  @moduledoc """
  Merchant schema representing businesses that can accept payments.
  
  ## Business Rules
  - Merchants must have unique API keys for authentication
  - Onboarding status controls merchant activation
  - KYC status determines compliance level
  - Both legacy and new KYC enum values supported for backward compatibility
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Onboarding status values
  @onboarding_statuses ~w(pending review activated suspended)
  
  # KYC status values - supports BOTH legacy and new system
  # Legacy: "verified" | New: "approved"
  # Test case TC5 explicitly requires both to be treated as valid
  @kyc_statuses ~w(not_started pending verified approved rejected)

  schema "merchants" do
    field :business_name, :string
    field :email, :string
    field :api_key, :string
    field :webhook_url, :string
    
    # Onboarding workflow status
    # Only "activated" allows transaction processing (TC4)
    field :onboarding_status, :string, default: "pending"
    
    # KYC compliance status
    # IMPORTANT: Both "verified" (legacy) and "approved" (new) are valid (TC5)
    field :kyc_status, :string, default: "not_started"
    
    # KYC tier for transaction limits (basic, standard, premium)
    field :kyc_tier, :string, default: "basic"
    
    # Contact information
    field :phone, :string
    field :contact_person, :string
    
    # Business metadata
    field :business_type, :string
    field :tax_id, :string
    
    # Timestamps
    timestamps(type: :utc_datetime)
    
    # Associations
    has_many :transactions, Isupayx.Transactions.Transaction
    many_to_many :payment_methods, Isupayx.Payments.PaymentMethod,
      join_through: Isupayx.Merchants.MerchantPaymentMethod
  end

  @doc """
  Changeset for merchant creation and updates.
  """
  def changeset(merchant, attrs) do
    merchant
    |> cast(attrs, [
      :business_name,
      :email,
      :api_key,
      :webhook_url,
      :onboarding_status,
      :kyc_status,
      :kyc_tier,
      :phone,
      :contact_person,
      :business_type,
      :tax_id
    ])
    |> validate_required([:business_name, :email, :api_key])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_inclusion(:onboarding_status, @onboarding_statuses)
    |> validate_inclusion(:kyc_status, @kyc_statuses)
    |> validate_inclusion(:kyc_tier, ~w(basic standard premium))
    |> unique_constraint(:api_key)
    |> unique_constraint(:email)
  end

  @doc """
  Checks if merchant can process transactions.
  
  ## Rules (from TC4 and TC5)
  - onboarding_status must be "activated"
  - kyc_status must be "verified" (legacy) OR "approved" (new)
  """
  def can_process_transactions?(%__MODULE__{} = merchant) do
    merchant.onboarding_status == "activated" and
      merchant.kyc_status in ["verified", "approved"]
  end

  @doc """
  Returns valid onboarding statuses.
  """
  def onboarding_statuses, do: @onboarding_statuses

  @doc """
  Returns valid KYC statuses (includes both legacy and new).
  """
  def kyc_statuses, do: @kyc_statuses
end

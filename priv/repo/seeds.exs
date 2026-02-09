# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Isupayx.Repo.insert!(%Isupayx.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Isupayx.Repo
alias Isupayx.Merchants.Merchant
alias Isupayx.Payments.PaymentMethod
alias Isupayx.Merchants.MerchantPaymentMethod

# Clear existing data (for development)
Repo.delete_all(MerchantPaymentMethod)
Repo.delete_all(Merchant)
Repo.delete_all(PaymentMethod)

IO.puts("Creating payment methods...")

# Create payment methods with limits from test cases
upi = Repo.insert!(%PaymentMethod{
  code: "upi",
  name: "UPI",
  description: "Unified Payments Interface",
  min_amount: Decimal.new("1.00"),
  max_amount: Decimal.new("200000.00"),  # TC6: ₹200,000 max
  is_active: true
})

credit_card = Repo.insert!(%PaymentMethod{
  code: "credit_card",
  name: "Credit Card",
  description: "Credit Card Payment",
  min_amount: Decimal.new("100.00"),  # TC7: ₹100 min
  max_amount: Decimal.new("500000.00"),
  is_active: true,
  requires_verification: true
})

debit_card = Repo.insert!(%PaymentMethod{
  code: "debit_card",
  name: "Debit Card",
  description: "Debit Card Payment",
  min_amount: Decimal.new("50.00"),
  max_amount: Decimal.new("100000.00"),
  is_active: true
})

netbanking = Repo.insert!(%PaymentMethod{
  code: "netbanking",
  name: "Net Banking",
  description: "Internet Banking",
  min_amount: Decimal.new("100.00"),
  max_amount: Decimal.new("1000000.00"),  # TC8: supports ₹250,000
  is_active: true
})

IO.puts("Created #{Repo.aggregate(PaymentMethod, :count)} payment methods")

IO.puts("Creating test merchants...")

# Merchant 1: Fully activated merchant (for successful test cases)
merchant_001 = Repo.insert!(%Merchant{
  business_name: "Test Merchant 001",
  email: "merchant001@example.com",
  api_key: "test_key_merchant_001",  # TC1 uses this key
  webhook_url: "https://webhook.example.com/merchant001",
  onboarding_status: "activated",  # TC4: must be "activated"
  kyc_status: "approved",  # TC5: "approved" (new system)
  kyc_tier: "premium",
  phone: "+919876543210",
  contact_person: "Test Contact"
})

# Merchant 2: Legacy KYC system (using "verified" instead of "approved")
merchant_002 = Repo.insert!(%Merchant{
  business_name: "Legacy Merchant 002",
  email: "merchant002@example.com",
  api_key: "test_key_merchant_002",
  webhook_url: "https://webhook.example.com/merchant002",
  onboarding_status: "activated",
  kyc_status: "verified",  # TC5: "verified" (legacy) should also work
  kyc_tier: "standard",
  phone: "+919876543211"
})

# Merchant 3: Inactive merchant (for TC4 testing)
merchant_003 = Repo.insert!(%Merchant{
  business_name: "Inactive Merchant 003",
  email: "merchant003@example.com",
  api_key: "test_key_merchant_003",
  webhook_url: "https://webhook.example.com/merchant003",
  onboarding_status: "review",  # TC4: not "activated"
  kyc_status: "approved",
  kyc_tier: "basic",
  phone: "+919876543212"
})

# Merchant 4: Pending KYC (for TC5 testing)
merchant_004 = Repo.insert!(%Merchant{
  business_name: "Pending KYC Merchant 004",
  email: "merchant004@example.com",
  api_key: "test_key_merchant_004",
  webhook_url: "https://webhook.example.com/merchant004",
  onboarding_status: "activated",
  kyc_status: "pending",  # TC5: KYC not approved
  kyc_tier: "basic",
  phone: "+919876543213"
})

IO.puts("Created #{Repo.aggregate(Merchant, :count)} merchants")

IO.puts("Associating payment methods with merchants...")

# Enable all payment methods for merchant 001 (primary test merchant)
for pm <- [upi, credit_card, debit_card, netbanking] do
  Repo.insert!(%MerchantPaymentMethod{
    merchant_id: merchant_001.id,
    payment_method_id: pm.id,
    is_enabled: true
  })
end

# Enable only UPI and netbanking for merchant 002
for pm <- [upi, netbanking] do
  Repo.insert!(%MerchantPaymentMethod{
    merchant_id: merchant_002.id,
    payment_method_id: pm.id,
    is_enabled: true
  })
end

# Enable all for merchant 003 (inactive, for testing)
for pm <- [upi, credit_card, debit_card, netbanking] do
  Repo.insert!(%MerchantPaymentMethod{
    merchant_id: merchant_003.id,
    payment_method_id: pm.id,
    is_enabled: true
  })
end

# Enable all for merchant 004 (pending KYC, for testing)
for pm <- [upi, credit_card, debit_card, netbanking] do
  Repo.insert!(%MerchantPaymentMethod{
    merchant_id: merchant_004.id,
    payment_method_id: pm.id,
    is_enabled: true
  })
end

IO.puts("Created #{Repo.aggregate(MerchantPaymentMethod, :count)} merchant-payment method associations")

IO.puts("\n✅ Seed data loaded successfully!")
IO.puts("\nTest API Keys:")
IO.puts("  - test_key_merchant_001 (Active, KYC Approved)")
IO.puts("  - test_key_merchant_002 (Active, KYC Verified - Legacy)")
IO.puts("  - test_key_merchant_003 (Inactive, onboarding_status: review)")
IO.puts("  - test_key_merchant_004 (Active, but KYC Pending)")

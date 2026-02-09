# Database Verification Script
# Run with: mix run verify_database.exs

alias Isupayx.Repo
alias Isupayx.Merchants.Merchant
alias Isupayx.Payments.PaymentMethod
alias Isupayx.Merchants.MerchantPaymentMethod
alias Isupayx.Transactions.Transaction

IO.puts("\n🔍 Database Verification Report")
IO.puts("=" |> String.duplicate(60))

# Check merchants
merchant_count = Repo.aggregate(Merchant, :count)
IO.puts("\n✓ Merchants Table:")
IO.puts("  Total merchants: #{merchant_count}")

if merchant_count > 0 do
  merchants = Repo.all(Merchant)
  for m <- merchants do
    status = if Merchant.can_process_transactions?(m), do: "✅ ACTIVE", else: "❌ INACTIVE"
    IO.puts("    - #{m.business_name}: #{status}")
    IO.puts("      API Key: #{m.api_key}")
    IO.puts("      Onboarding: #{m.onboarding_status} | KYC: #{m.kyc_status}")
  end
end

# Check payment methods
payment_method_count = Repo.aggregate(PaymentMethod, :count)
IO.puts("\n✓ Payment Methods Table:")
IO.puts("  Total payment methods: #{payment_method_count}")

if payment_method_count > 0 do
  payment_methods = Repo.all(PaymentMethod)
  for pm <- payment_methods do
    min = pm.min_amount || "None"
    max = pm.max_amount || "None"
    IO.puts("    - #{pm.name} (#{pm.code}): Min=₹#{min}, Max=₹#{max}")
  end
end

# Check merchant-payment method associations
mpm_count = Repo.aggregate(MerchantPaymentMethod, :count)
IO.puts("\n✓ Merchant-Payment Method Associations:")
IO.puts("  Total associations: #{mpm_count}")

# Check transactions
transaction_count = Repo.aggregate(Transaction, :count)
IO.puts("\n✓ Transactions Table:")
IO.puts("  Total transactions: #{transaction_count}")
if transaction_count == 0 do
  IO.puts("  (No transactions yet - this is expected)")
end

# Test specific merchant lookup (for API authentication)
IO.puts("\n✓ Testing Merchant Lookup by API Key:")
test_merchant = Repo.get_by(Merchant, api_key: "test_key_merchant_001")
if test_merchant do
  IO.puts("  ✅ Found: #{test_merchant.business_name}")
  IO.puts("  Can process transactions: #{Merchant.can_process_transactions?(test_merchant)}")
else
  IO.puts("  ❌ Merchant not found!")
end

# Test KYC backward compatibility
IO.puts("\n✓ Testing KYC Backward Compatibility:")
legacy_merchant = Repo.get_by(Merchant, api_key: "test_key_merchant_002")
if legacy_merchant do
  IO.puts("  Legacy merchant KYC status: #{legacy_merchant.kyc_status}")
  can_process = Merchant.can_process_transactions?(legacy_merchant)
  IO.puts("  ✅ Can process (legacy 'verified' accepted): #{can_process}")
end

# Test inactive merchant
IO.puts("\n✓ Testing Inactive Merchant Detection:")
inactive_merchant = Repo.get_by(Merchant, api_key: "test_key_merchant_003")
if inactive_merchant do
  can_process = Merchant.can_process_transactions?(inactive_merchant)
  expected = !can_process
  status_icon = if expected, do: "✅", else: "❌"
  IO.puts("  #{status_icon} Inactive merchant correctly blocked: #{!can_process}")
end

# Test payment method limits
IO.puts("\n✓ Testing Payment Method Validation:")
upi = Repo.get_by(PaymentMethod, code: "upi")
if upi do
  test_amounts = [
    {Decimal.new("1500.00"), :valid},
    {Decimal.new("250000.00"), :invalid}  # Exceeds UPI max
  ]
  
  for {amount, expected} <- test_amounts do
    case PaymentMethod.validate_amount(upi, amount) do
      {:ok, _} -> 
        icon = if expected == :valid, do: "✅", else: "❌"
        IO.puts("  #{icon} ₹#{amount}: Passed validation (expected: #{expected})")
      {:error, reason} -> 
        icon = if expected == :invalid, do: "✅", else: "❌"
        IO.puts("  #{icon} ₹#{amount}: Rejected (#{reason}) (expected: #{expected})")
    end
  end
end

# Database file check
db_path = "isupayx_dev.db"
if File.exists?(db_path) do
  file_size = File.stat!(db_path).size
  IO.puts("\n✓ Database File:")
  IO.puts("  Location: #{Path.absname(db_path)}")
  IO.puts("  Size: #{div(file_size, 1024)} KB")
else
  IO.puts("\n❌ Database file not found!")
end

IO.puts("\n" <> "=" |> String.duplicate(60))
IO.puts("✅ Database verification complete!\n")

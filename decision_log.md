# iSupayX Decision Log

**Project:** Payment Gateway Transaction Processing API  
**Technology:** Elixir 1.19.5, Phoenix 1.8.3, SQLite (via Ecto)  
**Start Date:** February 9, 2026  
**Developer:** Pritam (with AI assistance)

---

## Approach & Prioritization

### Initial Strategy

1. **Foundation First (Phase 1):** Set up Phoenix project, Git, decision log
2. **Data Model (Phase 2):** Database schemas before API logic
3. **Validation Pipeline (Phase 3):** Build all 5 layers with proper error handling
4. **API Endpoint (Phase 4):** Transaction creation with idempotency
5. **Event System (Phase 5):** Pub/Sub with retry logic and DLQ
6. **Concurrency (Phase 6):** Mutex implementation and race condition demos
7. **Testing & Docs (Phase 7):** Ensure 70%+ test coverage

### Time Allocation Strategy

- 20% on database design and state machine (foundational correctness)
- 30% on validation pipeline (most complex, 5 layers with error standardization)
- 20% on event system (async, retry, DLQ, back-pressure)
- 15% on concurrency/mutex (critical but smaller scope)
- 15% on testing and documentation

### Why This Order?

- **Database first:** Can't validate entities without schemas
- **Validation before API:** Ensures we can't accidentally skip layers
- **Events after core:** Transaction must exist before we can publish events
- **Mutex last:** Independent feature, can be built after core flow works

---

## AI Interaction Log

### Interaction #1: Project Setup

**Prompt:** "Create Phoenix project with --no-html --no-assets --database sqlite3"  
**AI Response:** Attempted to run `mix phx.new` directly  
**Issue:** Elixir was not installed on Windows system  
**Fix:** Guided user through Chocolatey installation of Elixir/Erlang, then manually refreshed PATH in PowerShell session  
**Learning:** Always check prerequisites before assuming build tools exist

### Interaction #2: [To be documented as we progress]

**Prompt:** TBD  
**AI Response:** TBD  
**Issue:** TBD  
**Fix:** TBD

### Interaction #3: [To be documented]

### Interaction #4: [To be documented]

### Interaction #5: [To be documented]

---

## Validation Layer Analysis

### Test Case Requirements (from Question Paper)

#### Layer 1: Schema Validation (HTTP 400)

- **TC2:** Missing required field (amount) → `SCHEMA_MISSING_FIELD`
- **TC3:** Negative amount → `SCHEMA_INVALID_AMOUNT`
- **Required checks:**
  - All required fields present: amount, currency, payment_method, reference_id, customer
  - Data types correct (amount is float, email is string, etc.)
  - Formats valid (email regex, phone regex)
  - Amount > 0

#### Layer 2: Entity Validation (HTTP 403)

- **TC4:** Inactive merchant → `ENTITY_MERCHANT_INACTIVE`
  - Must check `onboarding_status` field
  - Only "activated" should pass
  - "review", "pending", etc. should fail
- **TC5:** Invalid KYC status → `ENTITY_MERCHANT_KYC_INVALID`
  - **IMPORTANT:** Must accept BOTH "verified" (legacy) AND "approved" (new)
  - This is a backward compatibility requirement
  - Fail on: "pending", "not_started", "rejected"

#### Layer 3: Business Rules (HTTP 422)

- **TC6:** Amount exceeds payment method max → `RULE_AMOUNT_ABOVE_MAX`
  - UPI max: ₹200,000
  - Need to confirm other payment method limits
- **TC7:** Amount below minimum → `RULE_AMOUNT_BELOW_MIN`
  - Credit card min: ₹100.00
  - Need to confirm other payment method minimums
- **Per-transaction limits:** TBD (need spec clarification)
- **KYC tier limits:** TBD (need spec clarification)

#### Layer 4: Compliance (HTTP 201 with flags)

- **TC8:** Large transaction flagging → `AMOUNT_REPORTING`
  - Threshold: ₹200,000
  - Transaction SUCCEEDS but gets flagged
  - Return in `metadata.compliance_flags` array

#### Layer 5: Risk/Velocity (HTTP 429)

- **Requirement:** More than 10 transactions in 5 minutes
- **Action:** Reject with HTTP 429
- **Per:** merchant? customer? Need clarification

### Identified Ambiguities

1. **Velocity control scope:** Is it per merchant, per customer, or per API key?
2. **KYC tier limits:** What are the different tiers and their limits?
3. **Payment method mins/maxs:** Only have UPI max (₹200k) and credit card min (₹100). Need others.
4. **Per-transaction limits:** Mentioned in requirements but not defined

---

## Contradictions Found

### Contradiction #1: KYC Status Enum Values

**Source 1:** Test case TC5 mentions "verified" (legacy) and "approved" (new)  
**Source 2:** [Need to check main spec when clarification requested]  
**Resolution:** Will implement BOTH as valid values for backward compatibility  
**Impact:** Database enum must allow both; validation logic must check both

### Contradiction #2: [To be documented]

### Contradiction #3: [To be documented]

---

## Hidden Dependencies

### Dependency #1: Payment Method Configuration

**Discovery:** Business rule validation (Layer 3) requires min/max amounts per payment method  
**Impact:** Need a `payment_methods` table with config fields, not just an enum  
**Solution:** Create PaymentMethod schema with configurable limits

### Dependency #2: Merchant-Payment Method Join Table

**Discovery:** Test cases imply merchants can only use certain payment methods  
**Impact:** Need many-to-many relationship with join table  
**Solution:** Create `merchant_payment_methods` join table (stores extra attributes beyond FKs)

### Dependency #3: [To be documented]

---

## Architecture Decisions

### Decision #1: Phoenix vs Pure Plug

**Choice:** Phoenix Framework  
**Rationale:**

- Phoenix.PubSub built-in (required for event system)
- Phoenix.Ecto integration simplifies database work
- Router provides clean API structure
- Testing support with ConnCase
- Minimal overhead since we disabled HTML/assets
  **Trade-off:** Slightly heavier than pure Plug, but functionality gains worth it

### Decision #2: SQLite for Simulation

**Choice:** SQLite via Ecto (not production-ready)  
**Rationale:**

- Requirement explicitly states "simulation only"
- No need for PostgreSQL/MySQL complexity
- Ecto abstractions remain the same
- Easy local testing without external dependencies
  **Production Note:** Would use PostgreSQL with connection pooling

### Decision #3: [To be documented]

---

## What I Would Do Differently

### With More Time

1. **Add structured logging:** Use Logger metadata for correlation IDs
2. **Implement proper secrets management:** Don't store API keys in plaintext
3. **Add rate limiting at router level:** Use Plug for global rate limits
4. **Implement webhook retry queue:** Persistent storage, not just in-memory
5. **Add monitoring:** Telemetry for validation failures, event processing times

### With Production Requirements

1. **PostgreSQL instead of SQLite:** Better concurrency, JSONB for metadata
2. **Redis for distributed mutex:** Real distributed locks, not ETS simulation
3. **Kafka/RabbitMQ for events:** Durable message broker vs PubSub
4. **API versioning strategy:** URL-based or header-based versioning
5. **Comprehensive audit trail:** Every state change logged with actor

---

## Known Limitations

### Current Limitations

1. **No authentication implementation yet:** X-Api-Key validation stub only
2. **Idempotency not implemented:** Planned for Phase 4
3. **ETS-based mutex is process-local:** Not truly distributed across nodes
4. **No database migrations yet:** Schemas designed but not migrated
5. **Test coverage incomplete:** Target is 70%+, currently at 0%

### Intentional Simplifications

1. **No actual HTTP webhooks:** Logging only per requirements
2. **No encryption at rest:** SQLite file is plaintext
3. **No API documentation:** No Swagger/OpenAPI spec
4. **Simplified error messages:** Production would need i18n

### Bugs Known But Unfixed

1. [To be documented as we find them]
2. [To be documented]

---

## Test Case Mapping

| Test Case | Layer       | Expected Status | Error Code                  | Implementation Status |
| --------- | ----------- | --------------- | --------------------------- | --------------------- |
| TC1       | -           | 201 Created     | -                           | ⏳ Pending            |
| TC2       | Schema      | 400             | SCHEMA_MISSING_FIELD        | ⏳ Pending            |
| TC3       | Schema      | 400             | SCHEMA_INVALID_AMOUNT       | ⏳ Pending            |
| TC4       | Entity      | 403             | ENTITY_MERCHANT_INACTIVE    | ⏳ Pending            |
| TC5       | Entity      | 403             | ENTITY_MERCHANT_KYC_INVALID | ⏳ Pending            |
| TC6       | Business    | 422             | RULE_AMOUNT_ABOVE_MAX       | ⏳ Pending            |
| TC7       | Business    | 422             | RULE_AMOUNT_BELOW_MIN       | ⏳ Pending            |
| TC8       | Compliance  | 201 + flags     | -                           | ⏳ Pending            |
| TC9       | Idempotency | 200/409         | -                           | ⏳ Pending            |
| TC10      | Auth        | 401             | -                           | ⏳ Pending            |

---

## Payment Method Constraints (From Test Cases)

| Payment Method | Minimum (INR) | Maximum (INR) | Notes                         |
| -------------- | ------------- | ------------- | ----------------------------- |
| UPI            | TBD           | 200,000       | From TC6                      |
| Credit Card    | 100.00        | TBD           | From TC7                      |
| Debit Card     | TBD           | TBD           | Need spec                     |
| Net Banking    | TBD           | No limit?     | TC8 uses netbanking for ₹250k |

**Questions to Ask:**

1. What are debit card limits?
2. What is credit card maximum?
3. What is UPI minimum?
4. Does netbanking have limits?

---

## State Machine Definition

### Transaction States

Based on test case TC1 returning "processing", need to define:

- `pending` → Initial state when created
- `processing` → Payment gateway processing
- `authorized` → Payment approved
- `failed` → Payment failed
- `cancelled` → Manually cancelled
- `refunded` → Money returned

### Allowed Transitions

- pending → processing ✓
- processing → authorized ✓
- processing → failed ✓
- authorized → refunded ✓
- authorized → cancelled ✗ (can't cancel after authorized)
- Any state → pending ✗ (no backwards to pending)

**Need clarification:** Full state diagram from specification

---

## Event System Design

### Event Envelope Schema

From requirements, events must have:

```elixir
%{
  event_id: UUID,
  event_type: String,  # "transaction.authorized"
  version: String,     # "1.0"
  timestamp: DateTime,
  source: String,      # "isupayx-api"
  correlation_id: String,  # Links related events
  data: Map,          # Actual event payload
  metadata: Map       # Extra context
}
```

### Topic Hierarchy

Requirement: "hierarchical topic patterns"

- Specific: `txn:transaction:authorized:merchant_123`
- Category: `txn:transaction:authorized:*`
- All: `txn:*`

**Question:** Should subscribers register for wildcards or do we fan-out manually?

### Retry Strategy

- Attempt 1: Immediate
- Attempt 2: 1 second delay
- Attempt 3: 5 seconds delay
- Attempt 4: 30 seconds delay
- After 4th failure: Move to DLQ

### Back-Pressure Rules

- If mailbox > 100 messages:
  - Drop non-critical events (what defines non-critical?)
  - Keep: `transaction.authorized`, `transaction.failed`
  - Log dropped events

**Questions:**

1. What other events are "critical"?
2. Should we send alert when back-pressure activates?

---

## Concurrency Patterns

### Distributed Mutex Requirements

From requirements (Section E):

1. Acquire lock with TTL
2. Owner verification on release
3. Automatic stale lock expiry
4. Convenience wrapper function `with_lock/4`

### ETS vs Agent Choice

**Choice:** TBD (need to evaluate)
**Considerations:**

- ETS: Faster, shared state, survives process crashes if named table
- Agent: Cleaner API, easier ownership tracking, dies with supervisor
  **Likely choice:** ETS with named table for persistence

### Race Condition Demo

Must show:

- Without mutex: Counter incremented by 10 processes → result < 10 (race condition)
- With mutex: Same scenario → result = 10 (correct)

---

## Next Steps

### Immediate Tasks (Phase 2)

1. ✅ Create Phoenix project
2. ✅ Initialize Git
3. ✅ Create decision_log.md
4. ⏳ Design Ecto schemas (Merchant, Transaction, PaymentMethod, join table)
5. ⏳ Create migrations
6. ⏳ Implement transaction state machine

### Questions to Ask User

1. Payment method min/max limits for debit card?
2. Full KYC tier definitions and limits?
3. Velocity control: per merchant, customer, or API key?
4. Complete state machine diagram?
5. Definition of "critical" vs "non-critical" events?

---

**Last Updated:** 2026-02-09  
**Status:** Phase 1 Complete - Project Initialized ✅

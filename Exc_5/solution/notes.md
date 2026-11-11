# Exercise 5 — Part 2: Line Guardian

## Stage A — Today's System

### Step 1: 20 Machines
- **Detector read:** `16,218` readings
- **Table count:** `19,460` rows (`3,242` readings missed by the detector)
- **Are the missing readings in the table?** Yes, all readings are stored in PostgreSQL.
- **Why did the detector never see them?**
  - The 4 line gateways (`PostgresSink`) insert batches in parallel transactions and wait up to `120 ms` (`rng.uniform(0, 0.12)`) before calling `COMMIT`.
  - PostgreSQL assigns the `id` at `INSERT` time, before the transaction is committed, whereas `SELECT` only sees committed rows.
  - think through this timeline: gateway 1 inserts rows that
    get the ids 100–114 and commits 100 ms later; gateway 2 inserts rows
    115–129 and commits at once. A row gets its `id` when it is inserted,
    but others see it only when it is committed. Which rows does the
    detector see when it polls in between, and which `id` does it remember?
     - When `baseline_detector.py` polls in between, it sees only rows 115–129 and updates `last_id = 129`.
     - Once Gateway 1 commits rows `100–114`, their IDs are `< 129`, so `WHERE id > 129` permanently skips them. When the next readings arrive, `seq` jumps ahead and the model counts the skipped rows as `missing`.

### Step 2: Full Plant (600 readings/s)
- **What happens to `delay`, `backlog`, and `missing`, and why?**
  - Every `model.score()` call takes **3 ms**, so one detector instance can score at most 1000 / 3 = 333 readings/s.
  - Because the plant produces **600 readings/s**, arrival rate exceeds capacity by ~267 readings/s:
    - **`backlog`** grows continuously by ~267 rows/s (~16,000 rows after 60s).
    - **`delay`** grows steadily (~0.45 s per second of runtime, reaching ~25–27 s after 60 s), violating **R3**.
    - **`missing`** increases initially while the detector is still polling near the tip of the table; once the backlog exceeds `LIMIT 2000`, all transactions for those older IDs have already committed by the time the detector reads them, so `missing` stops growing.

---

## Stage B — Decide

### Options vs. Requirements (R1–R4)

| Requirement | Option 1: Keep PostgreSQL, poll better (multiple sharded pollers) | Option 2: Write readings to Kafka |
|---|---|---|
| **R1 — Scale** (600/s -> 100,000/s) | **At risk:** 100,000 inserts/s plus continuous polling queries cause heavy overhead on a single relational DB. | **Meets:** Append-only partitioned logs easily handle 100,000 messages/s. |
| **R2 — Complete & ordered** (`seq` order per machine) | **At risk:** Requires polling by `(machine_id, seq)` instead of `id > last_id` | **Meets:** Using `key = machine_id` hashes all readings of a machine to the same partition in strict order; consumer group assigns each partition to one detector. |
| **R3 — Fresh** (<= 5s) | **At risk:** Polling intervals and DB lock add latency at high rates. | **Meets:** Consumer groups parallelize inference across N detector instances with low latency. |
| **R4 — Independent consumers** | **Fails:** Every additional consumer polls PostgreSQL directly, increasing read load and competing with inserts. | **Meets:** Each consumer service uses its own id and reads independently from Kafka without touching PostgreSQL. |

### Decision
**Choose Option 2 (Kafka for sensor streams).**
- It satisfies **R1–R4** natively: partitioning by `machine_id` guarantees per-machine ordering (**R2**), consumer groups scale out the 3 ms/reading model (**R1, R3**), and separate consumer groups isolate the archive and dashboard from both the detector and PostgreSQL (**R4**).

### Capacity Estimation
- **Single detector throughput:** 333.3 readings/s
- **Lab (600 readings/s):**
  - Minimum: 2 instances (666.66 readings/s) (90% load).
  - Recommended: With 3 instances, we have a little bit more room, because of the lower load
- **Full Rollout (100,000 readings/s):**
  - Minimum: 300 instances
  - Recommended: 350–400 instances (~75–83% load) with at least as many partitions.
- **Tipping Point (Option 1 vs. Option 2):**
  - Option 1 is sufficient when a single poller can keep up (< 250 readings/s), writes are low-rate and there is only one consumer.
  - Once throughput exceeds ~250–300 readings/s (requiring multiple independent real-time consumers), Kafka becomes necessary.

---
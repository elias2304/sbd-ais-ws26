# Exercise 6 - Card Sentinel: Real-Time Fraud Detection with CDC

## Part 1 - The Decision

I choose Option 4 (CDC) for this scenario.
- As already stated in the README, polling adds continous query load to the DB (Violating R1) and can miss rows, when the transactions commit out of order (Violating R2)
- Dual writes and Outbox require changing the card_processor.py payment path (Violating R1) and dual writes also risk losing events on crashes (Violating R2)

Log-based CDC reads the changes directly from the write-ahead log (WAL) in commit order without changing any code or adding load. 
The main cost is the replication slot: if the Debezium connector falls behing, PostgreSQL retains the unread WAL segments and the disk can fill up and halt the paymend path. In production, we can detext this early by monitoring the replication slot lag and the disk usage.
If we owned the payment path, I would choose the transactional Outbox, as it avoids WAL retention risks. It also lets the application explicitly define the event payload within the same transaction.
---

## Part 2 - The Pipeline in Three Runs

### Run 1 - Debezium's Defaults

- **Connector config:** Default `fraud-connector.json` (no partition count or message key configured).
- **Kafka UI check:**
  - Number of partitions in `fraud.public.transactions`: `1` (`partition 0`)
  - Message key: Primary key of the table, `{"id": ...}`
- **Prediction:**
  - The three velocity instances will not share the work because Debezium creates the topic with only 1 partition by default, and Kafka assigns a partition to at most one consumer instance per consumer group. Because a single velocity instance takes 2 ms per payment (max ~450-500 payments/s) and 1,000 payments/s arrive, lag will grow continuously and R4 will fail.
- **Scoreboard (velocity model):**
  ```text
  velocity model (card testing)
    R3  frauds caught          2/4  (50%)   FAIL  (>= 90 %)
    R3  false alerts           0   PASS  (at most 10 % of the flagged transactions)
    R4  alert latency p50/p95  22.4 s / 48.7 s   FAIL  (p95 <= 5 s after the commit)
  ```
- **Why this happened:**
  - No partition count was configured in the JSON, which created the topci with only one parition. With this, vel-1 got assigned, whil vel-2 and vel-3 stayed idle. One instance can only process around 500 payments/s, against a rate of 1,000 payments/s, making the backlog grow every second (R4) and leaving newer fraud episodes unprocessed in the queue (R3).
---

### Run 2 - More Partitions

- **Connector change:** Added `"topic.creation.default.partitions": "6"` and `"topic.creation.default.replication.factor": "1"`.
- **Agent partition assignment:** `vel-1` got `[0, 1]`, `vel-2` got `[2, 3]`, `vel-3` got `[4, 5]`.
- **Prediction:**
  - All three velocity instances will now process events in parallel and keep up with the 1,000 payments/s rate, so R4 will pass. However, R3 will fail because the event key is still the transaction primary key (`id`), which spreads a single cardholder's payments across all 6 partitions and all 3 velocity instances.
- **Scoreboard (velocity model):**
  ```text
  velocity model (card testing)
    R3  frauds caught          0/4  (0%)   FAIL  (>= 90 %)
    R3  false alerts           0   PASS  (at most 10 % of the flagged transactions)
    R4  no alerts   PASS  (<= 5 s)
  ```
- **Why this happened:**
  - Now there are 6 partitions split across 3 velocity instances, which handles the throughputs of 1,000 payments/s easily (passes R4). Debezium still used the primary key as the Kafka message key, so the 12 test payments of a stolen card were hashed across all partitions. Each instance only saw 4 payments and never reached the threshold to trigger the alert (failing R3)

---

### Run 3 - The Cardholder as the Key

- **Connector change:** Added `"message.key.columns": "public.transactions:user_id"`.
- **Kafka UI check:**
  - Message key: Cardholder ID, `{"user_id": ...}`
- **Prediction:**
  - The message key in the Kafka UI will now contain `user_id` instead of `id`. Because Kafka hashes the key to choose the partition, all payments from the same cardholder will land in the same partition and go to the same velocity instance in commit order, so both R3 and R4 will pass.
- **Scoreboard (velocity model):**
  ```text
  velocity model (card testing)
    R3  frauds caught          4/4  (100%)   PASS  (>= 90 %)
    R3  false alerts           0   PASS  (at most 10 % of the flagged transactions)
    R4  alert latency p50/p95  0.2 s / 0.4 s   PASS  (p95 <= 5 s after the commit)
  ```
- **Why this happened:**
  - Now, every payment of a cardholder are stored in the same partition and therefore to the same velocity agent instance. That instance sees all card-testing payments and triggers an alert on the 8th payment (passes R3). The partitions distribute the cardholder evenly across all velocity instances, so the latency stays low (passing R4)

---

### Closing Question - Debezium Defaults in Production

If the defaults had not been changed, nothing would have crashed and no error messages would have appeared in the logs. The lag would have grown silently, while the extra agents sat idle. With the same setup as in run 2, the the system would have looked completely healthy with a zero lag while missing pretty much every fraud.
- The first problem could be seen by monitoring the lag and alert latency
- The second problem could be tracked by alert volume, per-instance unique cardholder counts and by comparing it to the ground truth (confirmed chargebacks)

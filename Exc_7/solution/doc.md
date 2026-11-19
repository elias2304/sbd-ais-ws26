# Exercise 7 - From the log to the lake

## Section 1 - Why the Example Fails

In the first cell, run_once() calls read_new(None) and writes into the LAKE. Passing None means, that the job does not remember where it stopped and always reads the entire topic

- After the first run, the lake has 2,896,000 records with 0 duplicates and 0 missing records.
- After the second run, the job copies all records a second time into a new folder in LAKE. The lake now has ~6 million rows, so half is duplicate and the report fails.

---

## 1. The Decision

I chose **Architecture B (The lake is the truth)**.

Why Architecture B:

- Single Source of truth: The job reads its starting position directly from the lake (MAX(kafka_offset) + 1 per partition)). Because there is no state file, the data and the progress in the file can never be out of sync.
- Safe against crashes: Every run writes the files in STAGING first, which readers ignore. Only after all partitions finished wrting, the whole run folder is published into the lake with a rename step. If a runs fails, the lake stays untouched and the next run cleans the STAGING.
- Clean lake for readers: Every record is stored once, so any reader can query the files directly without a deduplication view.

Why not the others?

- Architecture A (State file): Writing data into the lake and updating the file are two different steps. If one finishes and the other fails, then the state file has a wrong offset saved.
- Architecture C (Remove duplicates when reading): There is going to be a lot of redundant data, that waste storage and each query takes extry time deduplicating. If a reader forgets to deduplicate, it gets wrong results

Main trade-off of Architecture B:
- lake_position() needs to check the lake at the start of every run to find the offset, and a crash after writing to STAGING means that the batch needs to be written again in the next run. 

### Implementation

```python
def run_once():
    # 1. where did the last run stop?
    start = lake_position()
    # 2. read what is new
    new = read_new(start)
    # 3. write it to staging
    run = write_files(new, STAGING)
    # 4. move the finished run into the lake in one step
    publish(run)
```

---

## 2. Explanation of the Result

All situations check_all pass with no duplicates and missing records:

1. First run: The lake is empty, so lake_position() return Null. All 2,896,000 records are written on STAGING and published into the LAKE (4 files, 38s)
2. New records arrive: 100,000 new records have arrived. lake_position() finds the last offset per partition in the lake, so only the new records are copied and published (7s)
3. Run stops WHILE writing: New records arrive and the run crashes after writing only the first partition into the staging. After the staging, the lake is untouched. On the next run, the staging folder is removed and writes all partitions cleanly, and publishes them.
4. Run stops AFTER writing: New records arrive and the run crashes after writing all partitions into STAGING. After the crash, the lake is untouched. The next run discards the unpublished folder and rewrites the batch entirely.

---

## 3. Output of `check_all`

```text
reset: lake, staging and state deleted

situation                                 in lake  duplicates  missing  not loaded    run  check
-----------------------------------------------------------------------------------------------
1 first run                             2,896,000           0        0           0  38.1s  PASS
2 new records arrive, run again         2,996,000           0        0           0   7.3s  PASS
3 nothing new, run again                2,996,000           0        0           0   0.5s  PASS
4 run stops WHILE writing: right after  2,996,000           0        0     100,000         PASS
  ... then the next run                 3,096,000           0        0           0   9.1s  PASS
5 run stops AFTER writing: right after  3,096,000           0        0     100,000         PASS
  ... then the next run                 3,196,000           0        0           0   8.4s  PASS
-----------------------------------------------------------------------------------------------
Exactly once after every run: YES
```

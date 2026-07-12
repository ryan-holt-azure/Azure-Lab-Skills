# Lab 09 — VM Operations End to End

**Domain:** Compute (20–25%) · **Week:** 2 · **Cost:** one B2s VM — deallocate
between steps, delete at the end

## Objectives (exam skills covered)

Configure Azure Disk Encryption · Move VMs between resource groups · Manage VM
sizes · Add data disks · Configure high availability

## Build

1. Create a **B2s VM**. **Resize** it while running (watch the reboot happen —
   resizing across hardware clusters forces a reboot).
2. **Add a 4 GiB data disk**, initialize it inside the OS, take a **snapshot**,
   then **create a new disk from that snapshot**.
3. Enable **encryption at host** (may need a feature registration + the VM
   deallocated first).
4. **Move the VM to another resource group.**
5. Deploy one VM into an **availability zone** and confirm it cannot later be
   moved into an **availability set** — zone vs. set membership is decided at
   creation and requires delete/recreate to change.

## Exam facts

- Resize = reboot, when the resize crosses hardware clusters.
- Availability **set** membership is decided at creation; changing it means
  delete/recreate.
- **Sets** = fault + update domains within **one datacenter**. **Zones** =
  physically **separate datacenters** — higher SLA (99.99% multi-zone vs.
  99.95% for a set).
- Managed disks don't "move" between regions — snapshot and copy instead.
- **Encryption at host** ≠ **Azure Disk Encryption** (BitLocker/dm-crypt inside
  the guest OS) ≠ **SSE with customer-managed key** — three different answers
  to three different questions.

## Pro / interview talking point

Deallocate when done, every time — this is the single habit the whole 30-day
credit budget depends on. Saying that explicitly in an interview is a small but
real signal of operational discipline.

## Cleanup

```bash
az group delete -n rg-lab09 --yes --no-wait
```

# Lab 17 — Network Watcher

**Domain:** Monitoring & Backup (10–15%) · **Week:** 4 · **Cost:** ~$0 — reuses
VMs from Labs 13 and 14

## Objectives (exam skills covered)

Monitor on-premises connectivity · Use Azure Network Watcher · Troubleshoot
external and virtual network connectivity

## Build

1. **IP Flow Verify** against the Lab 13 VM: test one blocked port and one
   allowed port, confirm the tool correctly identifies which NSG rule decided
   each outcome.
2. **Next Hop** on the Lab 14 route: confirm it reports where a given packet
   is actually routed.
3. **Connection Monitor** between the two peered VMs from Lab 12 — set up a
   continuous check, not a one-off test.
4. Enable **NSG flow logs** briefly and read one log entry to understand its
   structure.

## Exam facts

- Network Watcher is **regional** and auto-enabled per region as soon as a
  VNet is created there.
- **IP Flow Verify** answers "which NSG rule blocked this traffic."
  **Next Hop** answers "where is this packet being routed."
- **Connection Monitor** replaces the older classic connection troubleshoot
  tool for **continuous** (not one-time) checks.

## Pro / interview talking point

IP Flow Verify and Next Hop together solve the large majority of "can't reach
X" tickets without ever touching a console cable — knowing these tools by name
and use case is a fast way to sound like the first responder on a networking
incident, not someone guessing.

## Job posting relevance

This is the HIPAA/Sophos posting's "Utilize monitoring tools to proactively
identify and resolve infrastructure concerns" and "Perform root cause analysis
and document corrective actions" lines, verbatim. The business consequence of
*not* having these tools: a "can't reach X" ticket turns into hours of guessing
instead of a two-minute IP Flow Verify check — directly the "deployments/fixes
take too long, the whole business slows down" pattern from the business-problem
framework, applied to troubleshooting instead of shipping.

## Cleanup

No dedicated resource group — this lab only reads state from Labs 12–14's
resources. Ensure NSG flow logs are turned off before those RGs are deleted
(flow logs write to a storage account that otherwise keeps accumulating data).

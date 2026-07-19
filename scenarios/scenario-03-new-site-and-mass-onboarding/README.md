# Scenario 3 — New Location Opening, 30 New Hires Starting Monday

## Business context

A multi-location healthcare organization is opening a new clinic. Leadership
signed the lease three weeks ago; IT found out about the go-live date last
week. 30 new clinical staff start Monday and need accounts, and the new
clinic's network needs to reach the organization's central resources
(patient records systems, shared file storage) on day one.

## What gets reported

**Not this:** "Provision a VNet, configure peering, and create bulk user
accounts with dynamic group membership."

**This:** Two messages arrive the same week. From HR: *"We're onboarding 30
nurses and clinic staff starting Monday — can IT have accounts ready?"* From
the practice manager at the new site: *"Our internet is installed, but
nobody here can get to the shared drive or the scheduling system. Is that an
IT thing?"*

## Business consequence if unresolved

This is "deployments take too long → the whole business slows down," twice
over. Thirty clinical staff who can't log in on day one isn't an IT
inconvenience — it's clinic operations not functioning, patients not being
seen, and a manual scramble that a repeatable process would have prevented
entirely.

## Investigation / planning

Two separate problems that get conflated under time pressure — separate them
first:

1. **Identity**: 30 people need accounts, the right department/group
   membership, and licensing — by Monday, not created one-by-one under
   pressure Sunday night.
2. **Connectivity**: the new clinic's network needs a path to central Azure
   resources. This is a network design decision, not just "turn on
   internet."

## Resolution

### Identity (Lab 01)
1. Use **bulk operations** with a CSV to create all 30 accounts at once —
   Department = `Clinic`, Usage location set correctly for every row (the
   #1 thing that silently breaks license assignment if skipped).
2. Confirm the existing **dynamic group** (`grp-clinic-dynamic`, rule:
   `department -eq "Clinic"`) picks up all 30 automatically — nobody
   manually adds them one at a time.
3. Confirm **group-based licensing** applies to all 30 without individual
   license assignment.
4. **Do this Thursday, not Sunday night** — dynamic group membership isn't
   instant (can take 5-10 minutes, sometimes longer under load), and Usage
   Location mistakes are easiest to catch with two days of runway, not two
   hours.

### Connectivity (Lab 12, and the honest limitation below)
1. Stand up the new site's VNet with a non-overlapping address space.
2. **Peer it** to the central VNet (or, if this were a true physical
   on-premises site rather than another Azure VNet, the real-world pattern
   is a **site-to-site VPN Gateway** connecting the clinic's on-prem router
   to Azure — a hands-on lab this repo doesn't have yet, flagged honestly
   rather than pretending peering alone solves a true on-prem connection).
3. Confirm connectivity: a test resource at the new site can reach the
   shared file storage and scheduling system's private endpoints.
4. Confirm **DNS resolution** works from the new site (Lab 15) — a
   surprisingly common way this exact scenario fails: routing works, but
   the new site can't resolve the internal name of the resource it's
   routing to.

## Root cause

Leadership and HR treated this as a real-estate and staffing project with
IT as an afterthought — the lease was signed weeks before IT had a
timeline. The technical work here is fast once started; the actual failure
mode is being told about it too late to do it calmly.

## Prevention / hardening

- A **standard "new site" checklist** (VNet template, peering/VPN pattern,
  DNS validation, a documented turnaround time) so this becomes a known
  quantity instead of a scramble every time the business opens a location.
- A **standard "bulk onboarding" checklist** tied to the dynamic group
  pattern, with the Thursday-not-Sunday timing rule written down explicitly.
- Push for IT to be looped in at lease-signing, not go-live minus one week —
  a process fix, not a technical one, but the technical work only goes
  smoothly if this happens.

## Skills drawn from

| Lab | What it contributed |
|---|---|
| Lab 01 (Users/Groups/SSPR) | Bulk account creation, dynamic group, group-based licensing |
| Lab 12 (VNets/Peering) | New site network connectivity |
| Lab 15 (DNS) | Confirming name resolution actually works end to end |

## Interview framing (problem → action → result)

*"Our organization opened a new location with about a week's real notice to
IT, and 30 staff needed to be productive on day one. I used bulk CSV import
plus a dynamic group rule so all 30 accounts, correct department
assignment, and licensing were live automatically — no manual per-user
setup — and stood up the new site's network connectivity with peering,
validated end to end including DNS resolution, before staff arrived."*

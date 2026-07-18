# Lab 01 — Entra Users, Groups, Licenses, SSPR, Guests

**Domain:** Identity & Governance (20–25%) · **Week:** 1 · **Cost:** ~$0 (identity objects are free)

## Objectives (exam skills covered)

Create users and groups · Manage user and group properties · Manage licenses in
Microsoft Entra ID · Manage external users · Configure self-service password reset
(SSPR)

## Prerequisites (Lab 0 setup — do once)

1. portal.azure.com → sign in → top-right, click your name → note the **Directory
   (tenant)** name (`yourname.onmicrosoft.com`). You'll type it constantly.
2. Open **Cloud Shell** (`>_` icon) → choose **Bash** → confirm subscription:
   ```
   az account show --output table
   ```
3. **Activate the Entra ID P2 free trial**: search bar → Microsoft Entra ID → left
   menu **Licenses** → **All products** → **+ Try / Buy** → find **Entra ID P2 free
   trial** → **Activate** (100 licenses, 30 days). Without this, dynamic groups are
   greyed out and half this lab is impossible.
4. Naming convention: resource groups `rg-lab01`; users `test.nurse1`,
   `test.billing1`; groups `grp-clinic-assigned`, `grp-clinic-dynamic`.

## Build

### 1.1 — Create your first user by hand
- Entra ID → **Users** → **All users** → **+ New user** → **Create new user**.
- Basics: UPN `test.nurse1`, Display name `Test Nurse One`. Uncheck
  auto-generate password, set one you'll remember.
- Properties: Job title `RN`, Department `Clinic`, **Usage location: United
  States**. Usage location is not optional — skip it and license assignment fails
  later with an unhelpful error.
- Review + create.

### 1.2 — Create a control user
- Repeat 1.1: UPN `test.billing1`, Display name `Test Billing One`, Department
  `Billing`, Usage location United States. This user must **not** land in the
  clinic group — without a negative case you can't prove the dynamic rule works.

### 1.3 — Bulk-create three users from CSV
- Users → **Bulk operations** → **Bulk create** → **Download** the CSV template.
- Fill 3 rows: Department = `Clinic`, Usage location = `US`, Block sign in = `No`.
- Upload → Submit → check **Bulk operation results**.

### 1.4 — Assigned group vs. Dynamic group
- Entra ID → **Groups** → **+ New group** → Security → `grp-clinic-assigned` →
  Membership type **Assigned** → add Test Nurse One → Create.
- **+ New group** again → `grp-clinic-dynamic` → Membership type **Dynamic User**.
  (Greyed out? You skipped the P2 trial.)
- **Add dynamic query** → rule builder: `department Equals Clinic`. Raw syntax:
  ```
  (user.department -eq "Clinic")
  ```
- Save → Create. **Wait 2–10 minutes**, then open the group → Members → refresh.
  Nurse One and the three bulk users appear by themselves; Billing One does not.

### 1.5 — License the GROUP, not the person
- Entra ID → **Licenses** → **All products** → tick **Microsoft Entra ID P2** →
  **+ Assign** → **Users and groups** → select `grp-clinic-dynamic` (the group,
  not a person) → Assign.
- Open a user in the group → Licenses → license shows as **inherited from the
  group**.

### 1.6 — Self-service password reset (SSPR)
- Entra ID → **Password reset** → Properties: enabled = **Selected** → pick
  `grp-clinic-dynamic` → Save. (Pilot to one group — never flip to "All" on day
  one.)
- Authentication methods: methods required = **1** (lab shortcut only —
  production requires 2), tick Email + Mobile phone → Save.
- Registration: require registration on sign-in = Yes, days before reconfirm =
  180 → Save. Notifications: notify on reset = Yes → Save.
- **Test it as the user**: private window → aka.ms/sspr → sign in as
  `test.nurse1` → register a method → sign out → "Forgot my password" → reset.

### 1.7 — Invite an external guest
- Entra ID → **Users** → **+ New user** → **Invite external user** → enter a
  second email you own → Review + invite.
- Accept the invite from that inbox → refresh Users in the portal → new entry's
  **User type** reads **Guest**.

### 1.8 — Do it again in CLI
```bash
az ad user create --display-name "CLI Nurse" \
  --user-principal-name cli.nurse@YOURTENANT.onmicrosoft.com \
  --password 'ChangeMe!2026'

az ad group create --display-name grp-cli --mail-nickname grpcli

az ad group member add --group grp-cli \
  --member-id $(az ad user show --id cli.nurse@YOURTENANT.onmicrosoft.com --query id -o tsv)
```

## Exam facts

- Dynamic groups and SSPR-with-writeback require **Entra ID P1** (writeback also
  needs Entra Connect).
- Group expiration policies apply to **Microsoft 365 groups only**, not security
  groups.
- License assignment needs **Usage Location** set on the user.
- Guests get fewer default directory permissions than members. External
  collaboration settings control who can send invitations (members can, by
  default).
- Group-based licensing requires the target to have a Usage Location; assign the
  license to the group, not each user.

## Pro / interview talking point

Chain it together: new nurse created with `Department = Clinic` → dynamic group
grabs her → group-based licensing gives her software → SSPR lets her fix her own
password. Nobody clicked "add member." That chain **is** onboarding automation at
a real org — a strong interview story, and directly relevant to any healthcare or
enterprise IT role.

## Job posting relevance

The MSP-generalist posting names **Active Directory** as a preferred skill — this
lab is the cloud-native version of that (Entra ID, not on-prem AD/GPO; see Lab
02's caveat). More specifically, group-based licensing at scale is exactly the
"onboarding 30 people, not 1" problem an MSP handling multiple customer
organizations runs into constantly — the same "handling multiple customers"
requirement that motivated the [Lighthouse bonus lab](../bonus-lighthouse-msp/README.md).

## Cleanup

Delete the test users, both groups, and the guest invite. Identity objects don't
bill, but stale accounts are exactly what fails an access-review audit — clean up
the same discipline as a billed resource.

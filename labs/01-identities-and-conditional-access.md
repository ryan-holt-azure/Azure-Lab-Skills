# Lab 01 — Halsted Staff Identities, Licensing, Guests, SSPR and Conditional Access

> **Scenario:** HLG's 10 staff need cloud identities: IT in Chicago, operations in Amsterdam and Singapore, plus Finance and Compliance. An EU partner, *Northbridge Freight*, needs guest access to the EU spoke. The helpdesk wants self-service password reset, and the CISO wants MFA for admins and anyone touching Azure management.
>
> **Time:** ~3 h · **Cost:** $0 (uses the P2 trial from Lab 00) · **Prereqs:** Lab 00

## What you'll build

```
Users (10 staff + break-glass + 1 guest)
 ├─ Assigned groups:  grp-hlg-it-admins · grp-hlg-network-ops · grp-hlg-finance
 │                    grp-hlg-auditors · grp-hlg-data-analysts · grp-hlg-sspr-pilot · grp-hlg-eu-partners
 ├─ Dynamic groups:   grp-hlg-eu-ops · grp-hlg-apac-ops · grp-hlg-all-staff
 ├─ Licensing:        Entra ID P2 → grp-hlg-all-staff (group-based)
 ├─ SSPR:             enabled for grp-hlg-sspr-pilot
 └─ Conditional Access: CA001 admins MFA · CA002 country block (report-only) · CA003 Azure management MFA
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create users and groups | Tasks 1, 2, 4 |
| Manage user and group properties | Tasks 3, 4 |
| Manage licenses in Microsoft Entra ID | Task 5 |
| Manage external users | Task 6 |
| Configure self-service password reset (SSPR) | Task 7 |

**Beyond the outline:** Conditional Access (Task 8). It's on SC-300/AZ-500 rather than AZ-104, but it's in the HLG brief and it's a strong portfolio item.

---

## Task 1 — Create the break-glass account and the first two staff by hand

**Why it matters:** The exam tests the portal flow and the properties it asks for. Do these by hand; Task 2 handles the rest in bulk.

### 1a. Emergency access (break-glass) account
1. **Microsoft Entra ID** → **Users** → **New user** → **Create new user**.
2. UPN `hlg-breakglass01@<tenant>.onmicrosoft.com`, display name `HLG Break Glass 01`. Use a long generated password and store it offline.
3. **Assignments** → add **Global Administrator**. Create.
4. Sign in once as this account (InPrivate) and register a strong MFA method. A FIDO2 passkey is ideal; Authenticator on a separate device is fine for a lab.

> [!TIP]
> **🎯 EXAM TIP — Break-glass accounts** are cloud-only (no dependency on on-prem sync), hold Global Administrator, are **excluded from Conditional Access policies** that could lock you out, and are monitored (sign-in alerts). Mandatory Azure MFA still applies to them, which is why Microsoft recommends passkeys or certificate-based auth for these accounts.

### 1b. Priya and Marcus
Create both with **New user → Create new user**, filling in the **Properties** tab:

| Field | Priya Natarajan | Marcus Reyes |
|---|---|---|
| UPN | `priya.natarajan@<tenant>` | `marcus.reyes@<tenant>` |
| Job title | Cloud Administrator | Network Engineer |
| Department | IT Infrastructure | IT Infrastructure |
| Company name | Halsted Logistics | Halsted Logistics |
| Office location | Chicago HQ | Chicago HQ |
| City / Country | Chicago / United States | Chicago / United States |
| **Usage location** | **United States** | **United States** |
| Manager | — | Priya Natarajan |

> [!TIP]
> **🎯 EXAM TIP — Usage location** is required before a license can be assigned to a user, because license availability depends on country. Missing usage location is the classic reason a group-based license assignment shows an error for one user (you'll reproduce this in Task 5).

> [!TIP]
> **🎯 EXAM TIP — Create vs invite.** *Create new user* makes an internal member account in your tenant. *Invite external user* creates a B2B **guest** that authenticates with its home identity provider (Task 6). The exam often gives a partner scenario and asks which one to use.

> 📸 **Checkpoint 01-01** — Marcus's profile showing job info, usage location and manager. → `screenshots/lab-01/01-01-user-properties.png`

---

## Task 2 — Bulk-create the remaining eight staff

Pick **one** path. Path A is what the exam asks about; Path B is what you'd use at work.

### Path A — Portal bulk create (CSV)
1. **Users** → **Bulk operations** → **Bulk create** → **Download** the CSV template.
2. Open [`identity/hlg-staff-bulk-template.csv`](../identity/hlg-staff-bulk-template.csv) from this repo. Copy its data rows into the downloaded template, matching column headers. (Microsoft occasionally adds columns. If they differ, the downloaded template wins.)
3. Replace `__TENANT__` with your tenant prefix and `__PASSWORD__` with a temporary password per user. Save it as `hlg-staff-bulk.local.csv`. The `.local.csv` suffix is git-ignored, so the passwords never reach GitHub.
4. Upload → **Submit**. Open **Bulk operation results** to see per-row success or failure.

### Path B — Microsoft Graph PowerShell
In Cloud Shell (PowerShell):
```powershell
cd ~/clouddrive/az104-hybrid-labs
./identity/New-HlgStaff.ps1
```
This creates the users from [`identity/hlg-staff.csv`](../identity/hlg-staff.csv) (skipping Priya and Marcus if they exist), sets managers, and creates **all groups for Task 4**. Temporary passwords go to `identity/out/credentials.local.csv` (git-ignored).

> [!TIP]
> **🎯 EXAM TIP — Bulk operations** in the portal cover **create, invite, delete, download users** and **import/remove group members** from CSV. Results are downloadable per operation. With PowerShell, the current module is **Microsoft Graph PowerShell** (`New-MgUser`, `New-MgGroup`). The old AzureAD and MSOnline modules are retired, so treat them as wrong answers on newer questions.

> 📸 **Checkpoint 01-02** — Bulk operation results (Path A) or the script output (Path B). → `screenshots/lab-01/01-02-bulk-create.png`

---

## Task 3 — Manage user properties

1. **Block sign-in**: open Tom Brennan → **Edit properties** → **Settings** → uncheck **Account enabled**. Save. Then re-enable it.
2. **Reset password**: Tom → **Reset password**. Note that it generates a temporary password and forces a change at next sign-in.
3. **Revoke sessions**: Tom → **Revoke sessions**. This invalidates refresh tokens (useful when a laptop is stolen).
4. **Delete and restore**: delete Dana Kowalski → **Users** → **Deleted users** → select Dana → **Restore users**. Confirm her group memberships and properties came back.
5. **Edit in bulk**: select all three APAC/EU staff → note what you *can't* bulk-edit in the portal (most properties). That's why scripts exist.

> [!TIP]
> **🎯 EXAM TIP — Deleted users are soft-deleted for 30 days** and can be restored with their properties and memberships. After 30 days (or after **Delete permanently**) they're gone. A restored user keeps the same object ID.

> [!CAUTION]
> **⚠️ EXAM TRAP — Synced users.** For users synced from on-premises AD (Entra Connect / Cloud Sync), most properties are **read-only in Entra ID**. You change them on-premises and they sync up. If a question says "users are synchronized from AD DS" and asks where to change a job title, the answer is on-premises AD, not the portal.

> 📸 **Checkpoint 01-03** — The Deleted users blade with Dana selected for restore. → `screenshots/lab-01/01-03-restore-user.png`

---

## Task 4 — Groups: assigned, dynamic and Microsoft 365

If you used Path B, the groups exist already. Walk through the portal screens anyway and **create at least one assigned and one dynamic group by hand** (delete the script's version first if needed).

### 4a. Assigned security groups
**Groups** → **New group**:

| Group | Type | Membership | Members |
|---|---|---|---|
| `grp-hlg-it-admins` | Security | Assigned | Priya |
| `grp-hlg-network-ops` | Security | Assigned | Priya, Marcus |
| `grp-hlg-finance` | Security | Assigned | Dana |
| `grp-hlg-auditors` | Security | Assigned | Grace |
| `grp-hlg-data-analysts` | Security | Assigned | Elena |
| `grp-hlg-sspr-pilot` | Security | Assigned | Lotte, Wei Ling, Tom |

Set **Priya** as an **owner** of `grp-hlg-network-ops`. Owners can manage membership without an admin role.

### 4b. Dynamic security groups
**New group** → Security → **Membership type: Dynamic User** → **Add dynamic query** → **Edit** the rule syntax:

| Group | Rule |
|---|---|
| `grp-hlg-eu-ops` | `(user.department -eq "EU Operations")` |
| `grp-hlg-apac-ops` | `(user.department -eq "APAC Operations")` |
| `grp-hlg-all-staff` | `(user.userType -eq "Member") -and (user.department -ne null)` |

Before saving, use **Validate Rules** with Jonas (should match EU) and Arjun (should not). After creating, open **Members**. Processing can take a few minutes.

> [!TIP]
> **🎯 EXAM TIP — Group types and membership.**
> - **Security** groups grant access (RBAC, apps, licenses). **Microsoft 365** groups add a shared mailbox, calendar, SharePoint site and Teams.
> - Membership: **Assigned**, **Dynamic User**, **Dynamic Device**. Dynamic **device** membership is available for **security groups only**, not Microsoft 365 groups.
> - You **can't manually add** members to a dynamic group. Change the user's attributes or the rule.
> - Dynamic membership requires **Entra ID P1** (or P2).
> - "**Microsoft Entra roles can be assigned to the group**" must be chosen **at creation** and can't be changed later. Role-assignable groups can't be dynamic.

> [!CAUTION]
> **⚠️ EXAM TRAP — Changing a group from Assigned to Dynamic** removes all its manually added members. Members are recalculated from the rule. The exam likes asking what happens to existing members.

### 4c. A Microsoft 365 group (for contrast)
Create `HLG EU Team`: Group type **Microsoft 365**, membership **Dynamic User**, rule `(user.department -eq "EU Operations")`. Open it and compare the blades with a security group (expiration and naming policy apply to Microsoft 365 groups).

> 📸 **Checkpoint 01-04** — `grp-hlg-eu-ops` dynamic rule and its members. → `screenshots/lab-01/01-04-dynamic-group.png`

---

## Task 5 — Licenses: group-based assignment and a deliberate failure

1. **Microsoft Entra ID** → **Billing** → **Licenses** → **All products** → **Microsoft Entra ID P2** → **+ Assign** → **Users and groups** → select **`grp-hlg-all-staff`** → **Assignment options** (leave all service plans on) → **Assign**.
2. Open any staff member → **Licenses**. Note **Assignment paths: Inherited (grp-hlg-all-staff)**.
3. **Reproduce the usage-location error:** create a user `test.nolocation@<tenant>`, Department `IT Infrastructure`, and **no usage location**. Wait for the dynamic group to add them, then open **grp-hlg-all-staff → Licenses**. You'll see a license error for that user.
4. Fix it: set the user's **Usage location** to United States → back on the group's **Licenses** blade, select **Reprocess**. The error clears.
5. Direct assignment: assign P2 **directly** to `test.nolocation` as well. On the user's Licenses blade you now see **two assignment paths**. Remove the direct one.
6. Delete `test.nolocation` when you're done.

> [!TIP]
> **🎯 EXAM TIP — Group-based licensing:**
> - Requires **P1** (or a bundle that includes it) to *use* the feature.
> - Users inherit licenses from groups; removing a user from the group removes the inherited license.
> - **Nested groups aren't supported**: only direct members of the licensed group get the license.
> - Failure reasons you should recognize: **usage location missing**, **not enough licenses**, **conflicting service plans**.
> - A user can have the same license **directly and inherited**. Removing one path leaves the other.

> 📸 **Checkpoint 01-05** — The group Licenses blade showing the usage-location error, then cleared. → `screenshots/lab-01/01-05-license-error.png`

---

## Task 6 — External users: Northbridge Freight's contractor

1. **External Identities** → **External collaboration settings**. Review and set:
   - **Guest user access**: *Guest users have limited access to properties and memberships of directory objects* (default).
   - **Guest invite settings**: *Only users assigned to specific admin roles can invite guest users*.
   - **Collaboration restrictions**: note the allow/deny domain lists. Leave them open for now; Break-fix 2 uses this.
2. **Users** → **New user** → **Invite external user**:
   - Email: a **personal address you control** (a second Outlook.com account works)
   - Display name: `Northbridge Contractor`
   - Personal message: "Access to the HLG EU spoke"
3. Open the invitation email, **Accept**, and complete consent. Back in the portal, open the guest:
   - **User type** = Guest
   - UPN looks like `you_outlook.com#EXT#@<tenant>.onmicrosoft.com`
   - **B2B collaboration**: invitation state *Accepted*
4. Create assigned group `grp-hlg-eu-partners` and add the guest. Lab 04 gives this group Reader on the EU spoke.

> [!TIP]
> **🎯 EXAM TIP — External users:**
> - Guests are **B2B collaboration** users. They sign in with their own Entra ID, Microsoft account, Google or email one-time passcode. You never manage their password.
> - Who can invite is controlled by **Guest invite settings**. The **Guest Inviter** role allows inviting when invites are restricted to admins.
> - **Allow/deny domain lists** live under *Collaboration restrictions*. **Cross-tenant access settings** control B2B with specific Entra organizations (inbound/outbound, trust MFA from the partner).
> - Guests can be added to groups and granted Azure RBAC roles like any user.
> - You can **convert an external user to an internal user** (keeps the object ID and access), or change a guest's **User type** to Member.

> 📸 **Checkpoint 01-06** — The guest's profile showing User type: Guest and the #EXT# UPN. Blur your personal email. → `screenshots/lab-01/01-06-guest-user.png`

---

## Task 7 — Self-service password reset for the pilot group

1. **Microsoft Entra ID** → **Password reset** → **Properties** → **Self service password reset enabled: Selected** → select `grp-hlg-sspr-pilot` → Save.
2. **Authentication methods**: **Number of methods required to reset = 1**. Look at which methods are listed.
3. **Registration**: *Require users to register when signing in* = **Yes**; days before users are asked to reconfirm = **180**.
4. **Notifications**: notify users on password reset = Yes; notify all admins when other admins reset = Yes.
5. **Customization**: set a helpdesk link, for example `https://support.halsted.example/reset`.
6. Look at **On-premises integration** (password writeback) to see what it would need: Entra Connect or Cloud Sync, plus P1.
7. **Test it:** InPrivate window → sign in as Lotte → you're asked to register security info → register Authenticator or email. Sign out, then go to <https://aka.ms/sspr>, enter Lotte's UPN, and reset her password.

> [!NOTE]
> **🧭 Methods moved.** Since **30 September 2025**, *which* methods users can use for SSPR and MFA is managed in the unified **Authentication methods policy** (**Entra ID → Authentication methods → Policies**), not in the legacy SSPR blade. The legacy SSPR policy still controls the **number of methods required to reset** and the **administrator** SSPR policy. Exam questions written before the change still show the old blade, so know both.

> [!TIP]
> **🎯 EXAM TIP — SSPR facts:**
> - Scope: **None / Selected (one group) / All**.
> - **Administrators are always enabled** for SSPR with a stricter **two-gate** policy (two methods, no security questions). Your scoping doesn't apply to them.
> - Required methods: **1 or 2**.
> - **Password writeback** (reset in the cloud, written to on-prem AD) needs Entra Connect or Cloud Sync and **P1**.
> - SSPR for cloud users needs P1/P2 or a Microsoft 365 business plan. Free tenants get self-service password **change** only.

> 📸 **Checkpoint 01-07** — The SSPR Properties blade scoped to the pilot group, plus the reset success page. → `screenshots/lab-01/01-07-sspr.png`

---

## Task 8 — Conditional Access (beyond the AZ-104 outline)

> [!NOTE]
> **🧭 BEYOND THE OUTLINE.** Conditional Access isn't in the April 2026 AZ-104 skills list. Do this task for the HLG brief and your portfolio. It also matters in Lab 10, where Azure Files Kerberos needs a CA exclusion.

### 8a. Turn off security defaults
**Microsoft Entra ID** → **Overview** → **Properties** → **Manage security defaults** → **Disabled** → reason *My organization is using Conditional Access*.

> [!TIP]
> **🎯 EXAM TIP — Security defaults and Conditional Access are mutually exclusive.** Security defaults are free baseline MFA for everyone. Conditional Access (P1) replaces them with targeted policies.

### 8b. Named locations
**Security** (or **Protection**) → **Conditional Access** → **Named locations**:
- **+ IP ranges location** `Chicago HQ`: your current public IP as `/32` (search "what is my IP"). Check **Mark as trusted location**.
- **+ Countries location** `HLG operating countries`: United States, Netherlands, Singapore.

### 8c. Policies

| Policy | Users | Target resources | Conditions | Grant | State |
|---|---|---|---|---|---|
| `CA001-Admins-RequireMFA` | Include `grp-hlg-it-admins`; **exclude break-glass** | All resources | — | Require MFA | **On** |
| `CA002-Staff-BlockOutsideOperatingCountries` | Include `grp-hlg-all-staff`; exclude break-glass | All resources | Locations: include **Any location**, exclude **HLG operating countries** | Block access | **Report-only** |
| `CA003-AzureManagement-RequireMFA` | All users; **exclude break-glass** | *Windows Azure Service Management API* | — | Require MFA | **On** |

### 8d. Test and interpret
1. **What If** (Conditional Access → Policies → What If): user = Priya, cloud app = Office 365 or *All*, location = Chicago HQ IP → CA001 applies. Try Lotte with country = Brazil → CA002 shows as report-only *Block*.
2. Sign in as **Priya** at <https://myapps.microsoft.com>. CA001 forces MFA registration and an MFA prompt.
3. **Sign-in logs** → open Priya's sign-in → **Conditional Access** tab (Success/Failure/Not applied) and **Report-only** tab.

> [!CAUTION]
> **⚠️ LOCKOUT TRAP.** Always exclude a break-glass account before turning a policy **On**, and start risky policies in **Report-only**. A policy that blocks "All users / All resources" without an exclusion locks out everyone, including you.

> 📸 **Checkpoint 01-08** — The CA policy list, plus Priya's sign-in log Conditional Access tab. Blur IP addresses. → `screenshots/lab-01/01-08-conditional-access.png`

---

## Break-fix challenges

1. **"Arjun isn't in grp-hlg-apac-ops."** Run `Set-MgUser -UserId arjun.mehta@<tenant> -Department "APAC Ops"` (or edit in the portal) and wait. Diagnose it from the group's **Validate Rules** without looking at the rule first.
2. **"Tom from the service desk can't invite a vendor guest."** Tom has no admin role and invites are admin-only. Fix it with least privilege.
3. **"Wei Ling's license shows an error."** Remove her usage location and reprocess. Write down the exact error text in your notes.

<details><summary>Fixes</summary>

1. The rule compares `user.department` to `"APAC Operations"`, and "APAC Ops" doesn't match. Fix the attribute, not the group. You can't add members to a dynamic group manually.
2. Assign Tom the **Guest Inviter** Entra role. Don't loosen tenant-wide guest invite settings for one person.
3. Set usage location → group **Licenses** → **Reprocess**.
</details>

---

## Knowledge check

1. You need all users in the Sales department to get a Microsoft 365 license automatically, including new hires. What do you configure, and what's the minimum Entra license?
2. A dynamic **device** group must contain all Windows devices. Can it be a Microsoft 365 group?
3. You need to grant a partner's employees access with their own corporate credentials. Create users or invite?
4. Admins in your tenant aren't in the SSPR-enabled group. Can they use SSPR?
5. You created `grp-helpdesk` and now want to assign it the *Helpdesk Administrator* Entra role. The option is greyed out. Why, and what do you do?

<details><summary>Answers</summary>

1. A dynamic user group with rule `(user.department -eq "Sales")` plus group-based licensing. Minimum Entra ID P1. Users also need a usage location.
2. No. Dynamic device membership is security groups only.
3. Invite them as B2B guests (optionally with cross-tenant access settings).
4. Yes. Administrators are always enabled for SSPR with the two-gate policy, regardless of scoping.
5. The group wasn't created as role-assignable, and that can't be changed afterwards. Create a new group with *Microsoft Entra roles can be assigned to the group* = Yes (assigned membership).
</details>

---

## Clean up

Nothing here costs money. Keep everything: later labs use these users and groups. When the P2 trial ends, dynamic groups stop updating and CA policies stop applying. Before that happens, either buy a P1 license or delete the CA policies (Lab 16 teardown).

## 📣 Document it

```bash
git add notes/lab-01.md screenshots/lab-01 && git commit -m "Lab 01: Entra identities, dynamic groups, group licensing, B2B, SSPR, Conditional Access"
```

**LinkedIn post template:**
> Lab 01 of my AZ-104 hybrid build: identity for a fictional 3-continent logistics company.
>
> 🔹 10 staff created by hand, by CSV bulk import and with Microsoft Graph PowerShell
> 🔹 Dynamic groups by department (EU Ops, APAC Ops) driving group-based licensing
> 🔹 Reproduced and fixed a license failure caused by a missing usage location, a classic exam scenario
> 🔹 B2B guest access for a partner, with invites locked to admins and the Guest Inviter role
> 🔹 SSPR for a pilot group, and the September 2025 move to the unified Authentication methods policy
> 🔹 Conditional Access: admin MFA, Azure-management MFA, a report-only country block, and a break-glass exclusion
>
> Biggest lesson: start risky CA policies in report-only and exclude a break-glass account before you turn anything on.
> #Azure #AZ104 #EntraID #IdentityAndAccess #LearningInPublic

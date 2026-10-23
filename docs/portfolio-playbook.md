# Portfolio Playbook — Turning These Labs into Evidence

You don't use Azure at your current job, so this repo is your Azure work history. Make it easy for a hiring manager to see what you built, how you think, and that you're honest about the scope.

## 1. Make the repo scannable in 30 seconds

At the top of the README (already scaffolded), keep:
1. **One sentence:** what you built.
2. **The architecture diagram.**
3. **Results:** labs completed, total spend, the 3 lessons you'd tell a teammate.
4. **Evidence index:** link straight to your best write-ups (capstone incidents first).

Pin the repo on your GitHub profile. Add your Credly AZ-104 badge to the README when you pass.

## 2. Write each lab up the same way

Use [`notes/TEMPLATE.md`](../notes/TEMPLATE.md). The sections reviewers actually read:
- **What I built**, in your own words, not copied from the lab.
- **What broke and how I fixed it.** This is the closest thing to on-the-job experience. Symptom → hypothesis → evidence → fix.
- **Evidence:** 2–4 redacted screenshots per lab, each proving one thing.

The **Lab 16 incident write-ups** are your strongest material. Treat them like real post-incident reviews.

## 3. LinkedIn: a steady cadence beats one big post

- **One post per lab** (templates are at the bottom of every lab), 2–3 per week.
- **1–3 screenshots** per post. Show the result (Connected, 200 vs 403, the failing hop), not a wall of settings.
- Say it's a **lab**. "In my lab environment" is honest and still impressive. Never imply production experience you don't have.
- End with a lesson, or a question that invites people to comment ("How do you handle hybrid DNS for private endpoints?").
- Run `scripts/secret-scan.sh` and check every image before posting. Your tenant name and home IP count as personal data.

## 4. Translate it into experience bullets (a "Projects / Home lab" section)

Examples, so keep only what you actually did:
- Designed and deployed a **4-region hub-and-spoke Azure network** with Bicep (subscription-scope, modular), including global peering, NVA routing with UDRs, and a **site-to-site VPN** to a simulated on-prem datacenter.
- Implemented **governance at management-group scope**: Azure Policy initiatives (Deny/Modify with remediation), resource locks, tagging standards, budgets and Advisor alerts.
- Built **least-privilege RBAC** for five teams across four scopes, including conditional RBAC Administrator delegation and data-plane roles for storage.
- Secured PaaS with **private endpoints and private DNS**, service endpoints, storage firewalls, customer-managed keys, SAS with stored access policies, and Entra Kerberos for Azure Files.
- Delivered **observability and resilience**: AMA/DCR, KQL, metric/log/activity alerts with processing rules, Connection monitor, VM/disk backup, and **Site Recovery test failover** to a secondary region.
- Ran an **8-incident break-fix exercise** (NSG, UDR, DNS, locks, RBAC, LB probes) with written root-cause analyses.

## 5. Interview stories to prepare (STAR)

| Prompt | Use |
|---|---|
| "Tell me about a time something didn't work the way you expected." | Lab 07 hybrid DNS: tunnel up, 403 anyway |
| "How do you avoid breaking production with IaC?" | Lab 03 drift trap + `what-if` + Complete mode in a sandbox |
| "How would you troubleshoot 'the app is down'?" | Lab 16 method: DNS → route → NSG → app → identity → governance |
| "How do you control cloud cost?" | Budgets, SKU policy, auto-shutdown, separate templates for expensive parts, the final cost report |
| "Explain least privilege with an example." | Lab 04: Owner can't read blobs with Entra auth; analysts get data roles without keys |

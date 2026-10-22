# Screenshot redaction checklist

Check every image at 100% zoom before committing. A text scanner can't read images.

| Always blur or crop | Where it hides |
|---|---|
| Subscription ID, tenant ID, object/client IDs | Overview blades, JSON view, the browser address bar, IAM blades |
| Your home or office public IP | Named locations, storage firewall, access restrictions, ipify output |
| Real email addresses and your tenant domain | User lists, sign-in logs, alert emails |
| Access keys, connection strings | Storage access keys, Key Vault, app settings |
| SAS tokens (anything after `?` containing `sig=`) | Generate SAS dialogs, terminal output |
| VPN shared key, passwords | Connection blades, terminals |

Quick checks:
1. Crop out the browser address bar (it contains the tenant and subscription).
2. Crop out the top-right account badge.
3. Run `clear` before terminal screenshots.
4. Use a solid box or heavy pixelation, not light blur.

## Naming

Save each checkpoint in its lab's `screenshots/` folder using the name in the
evidence table, e.g. `labs/lab-00-setup-tooling-cost-guardrails/screenshots/00-01-subscription-offer.png`.
Use PNG, crop to the relevant blade, keep files under about 500 KB.
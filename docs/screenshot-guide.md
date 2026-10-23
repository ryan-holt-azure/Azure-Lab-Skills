# Screenshot Guide — Evidence You Can Post Publicly

Screenshots turn "I studied" into "I built". They also leak secrets more often than code does. Follow this guide for every checkpoint.

## Naming and placement

Each lab marks checkpoints like this:

> 📸 **Checkpoint 05-04** — The route table with the route and subnet association… → `screenshots/lab-05/05-04-udr-nva.png`

- Save to exactly that path. `scripts/check-coverage.py` checks the IDs, and your notes link to them.
- Use **PNG**, crop to the relevant blade, and keep each file under ~500 KB (resize to ~1600 px wide).
- Multiple images for one checkpoint: `05-04a-…png`, `05-04b-…png`.
- Embed in your notes with alt text that says what's proven:
  `![Checkpoint 05-04 — WEU effective routes showing 10.40.0.0/16 via VirtualAppliance 10.20.4.4](../screenshots/lab-05/05-04-udr-nva.png)`

## 🔒 Redact before you save

| Always blur or crop | Where it hides |
|---|---|
| **Subscription ID**, **tenant ID**, **object/client IDs** | Overview blades, JSON view, URLs in the address bar, IAM blades |
| **Your home/office public IP** | CA named locations, storage firewall, access restrictions, `ipify` output |
| **Email addresses / UPNs with your tenant name** | User lists, sign-in logs, alert emails (fictional staff names are fine; your tenant domain isn't) |
| **Access keys, connection strings** | Storage → Access keys, Key Vault secrets, App settings with secrets |
| **SAS tokens** (anything after `?` containing `sig=`) | Generate SAS dialogs, terminal output |
| **VPN shared key**, **passwords** | Connection blades, terminals, cloud-init |
| **Public IPs of gateways and load balancers** | Optional, but blur them if the resources still exist |

Quick checks:
1. Look at the **browser address bar**. Portal URLs contain your tenant domain and subscription ID. Crop it out.
2. Look at the **top-right account badge**: your sign-in name and directory. Crop it out.
3. In terminal screenshots, run `clear` first and make sure no earlier command echoed a secret.

## Tools

| OS | Capture + blur |
|---|---|
| Windows | **Snipping Tool** (Win+Shift+S) then blur/pen. **ShareX** has auto-blur regions and annotation. **Greenshot** has an obfuscate tool. |
| macOS | **Cmd+Shift+4**, then Preview → Markup (shapes/redact). **CleanShot X** blurs. |
| Linux | **Flameshot** (blur/pixelate built in) |

Use a solid box or heavy pixelation rather than light blur. Light blur on text can sometimes be reversed.

## Make them readable

- Portal **zoom 90%**, so the whole blade fits.
- Close Copilot and notification panes.
- Use the same portal theme for every screenshot (light or dark).
- Add a red box or arrow on the one thing that matters: the "Connected" status, the deny rule, the 403.
- For before/after evidence (break-fix), put two crops side by side.

## Before you push

```bash
bash scripts/secret-scan.sh          # text files: GUIDs, SAS sigs, keys, passwords
git diff --cached --stat             # did any unexpected files sneak in?
```
Then **open every new PNG once at 100% zoom** and look for the items in the redaction table. The scanner can't read images.

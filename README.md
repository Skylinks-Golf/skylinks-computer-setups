# skylinks-computer-setups

Everything about setting up and using Skylinks computers, PC and Mac: scripts, docs, checklists.
One repo, public on purpose so machines can fetch scripts without credentials.
**Never commit passwords, tokens, customer or member data, or anything personal.**

| Folder | What it is |
| --- | --- |
| `windows/register-setup/` | One-time provisioning of a register PC (Chrome, Slack, power, bloatware, Wi-Fi). |
| `windows/register-startup/` | What a register does at every logon: opens and arranges the Chrome windows. Self-updating from `master`. |
| `windows/admin-laptop/` | Setup for admin Windows laptops. Not for registers. |
| `mac/admin-macbook/` | Setup for admin MacBooks. |
| `mac/` (`setup.sh`, `Brewfile`) | Original Homebrew baseline for a staff Mac. Overlaps `admin-macbook`; fold in or retire. |
| `docs/` | Proposals and background. `project_proposal.md` is the original plan and still mentions the old `skylinks-scripts` URLs. |

Each folder has its own README. Setup flows pin to the tag `device-setup-v2` so a machine runs a reviewed
version; the register startup follows `master` on purpose so fixes reach the registers by themselves.

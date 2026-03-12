<p align="center">
  <img src="assets/banners/default.jpg" alt="Remnasale" width="100%">
</p>

<h1 align="center">Remnasale</h1>
<p align="center">
  <b>Telegram bot for selling VPN subscriptions with Remnawave Panel integration</b>
</p>

<p align="center">
  <a href="https://github.com/DanteFuaran/Remnasale/releases"><img src="https://img.shields.io/badge/version-0.2.0-blue?style=flat-square" alt="version"></a>
  <img src="https://img.shields.io/badge/python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white" alt="python">
  <img src="https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white" alt="docker">
  <a href="README.md"><img src="https://img.shields.io/badge/lang-RU-lightgrey?style=flat-square" alt="RU"></a>
  <a href="README_EN.md"><img src="https://img.shields.io/badge/lang-EN-blue?style=flat-square" alt="EN"></a>
</p>

---

## 🚀 Quick Start

```bash
cd /opt && bash <(curl -s https://raw.githubusercontent.com/DanteFuaran/Remnasale/main/remnasale-install.sh)
```

> After installation, manage the bot with the **`rs`** or **`remnasale`** command

---

## ✨ Features

<details>
<summary>Show details</summary>

<br>

<details>
<summary>💳 Payment Gateways</summary>

<br>

The bot supports **9 payment methods**, multiple can be active simultaneously:

- ⭐ **Telegram Stars** — Native Telegram payments
- 💳 **YooKassa** — Bank cards, SBP, e-wallets
- 💳 **YooMoney** — YooMoney e-wallet
- 💳 **Lava** — Russian payment gateway
- 💳 **Platega** — Russian payment gateway
- 💳 **Robokassa** — Multi-channel acquiring
- 🔐 **Cryptomus** — Cryptocurrency payments
- 💎 **Heleket** — International crypto payments
- 💰 **Cryptopay** — Crypto acquiring

In addition to external gateways, an **internal balance** system is supported — top-up, transfers between users, cashback.

</details>

<details>
<summary>📦 Subscription Plans</summary>

<br>

Flexible plan management directly from the bot without restart:

- **4 limit types:** traffic / devices / traffic+devices / unlimited
- **Unlimited** periods and price tiers
- **Multi-currency** — RUB, USD, EUR, XTR (Telegram Stars)
- **6 availability modes:** all / new / existing / invited / allowed / trial
- **Tags** — bind a plan to a Remnawave tag for auto-sync
- **Squads** — support for internal and external Remnawave squads
- **Global discount** — percentage or fixed discount on all plans

</details>

<details>
<summary>🎁 Free Trial</summary>

<br>

- Free trial access without a payment method
- Dedicated trial plan
- Referral trial subscription (invite-only)
- Restriction: new users only

</details>

<details>
<summary>📱 Extra Devices</summary>

<br>

- Sell additional device slots
- **3 billing modes:** one-time / monthly / until subscription ends
- Configurable minimum duration and price
- Auto-renewal with notifications
- Removal and management from user menu

</details>

<details>
<summary>🎟 Promo Codes</summary>

<br>

- **Percentage and fixed** discounts
- Activation limit and expiry date
- Bind to specific users or plans
- Random code generation
- Reward types: discount / free subscription / bonus balance / extra days

</details>

<details>
<summary>👥 Referral System</summary>

<br>

- **2 referral levels**
- Reward type: money or extra days
- Accrual strategy: first payment / every payment
- Form: fixed amount or percentage
- **Cashback** on every referral payment
- Customisable invite message with preview
- Referral and payout history

</details>

<details>
<summary>💰 Balance & Transfers</summary>

<br>

- Top-up via any connected payment gateway
- Transfers between users with configurable commission
- **2 balance modes:** separate (main + bonus) / unified
- Min/max transfer amount settings
- Transfer history

</details>

<details>
<summary>🔔 Notifications</summary>

<br>

**User notifications (automatic):**

| Event | Description |
|-------|-------------|
| ⏰ Subscription expiring | 3, 2 and 1 day before expiry |
| ❌ Subscription expired | At expiry and 1 day after |
| 🌐 Traffic exhausted | When traffic limit is exceeded |
| 🎁 Referral attached | When a new referral registers |
| 💰 Reward received | When a referral reward is credited |

**System notifications (to admin):**

New registrations, purchases, promo activations, device change (HWID), node status, financial operations, bot lifecycle, updates.

</details>

<details>
<summary>📢 Broadcasts</summary>

<br>

- Send by segment: **all / by plan / subscribed / unsubscribed / expired / trial**
- Text, photo, video, document support
- Inline buttons in broadcasts
- Preview before sending
- Delivery stats and mid-broadcast stop

</details>

<details>
<summary>🔓 Access Modes</summary>

<br>

| Mode | Description |
|------|-------------|
| 🌍 **Public** | Registration and purchases open to everyone |
| ✉️ **Invite only** | Only users with a referral link |
| 🔒 **Closed** | All actions forbidden |

Independent control of **registration** and **purchases**.  
Additional conditions: mandatory rules acceptance, mandatory channel subscription.

</details>

<details>
<summary>🌍 Multilanguage</summary>

<br>

| Language | |
|----------|-|
| 🇷🇺 Russian | ✅ |
| 🇺🇦 Ukrainian | ✅ |
| 🇬🇧 English | ✅ |
| 🇩🇪 German | ✅ |

- Auto-detect from user's Telegram language
- Option to lock a single language for all users
- Extensible: add a folder to `assets/translations/` and list it in `APP_LOCALES`

</details>

<details>
<summary>📡 Remnawave Integration</summary>

<br>

- Real-time user and subscription sync via webhook
- Create, extend, change plans directly in Remnawave Panel
- Auto-update plan name when changed in the panel
- User import from Remnawave Panel
- Node and server status monitoring
- Squad and inbound support

</details>

<details>
<summary>👨‍💼 Dashboard (Admin Panel)</summary>

<br>

#### 👥 Users
- Search by ID, username, name
- View and edit profile
- Balance management (main + bonus)
- Role assignment (USER / ADMIN / DEV)
- Block / unblock
- Purchase history and referral list
- Direct subscription edit (plan, traffic, devices, expiry)
- Sync with Remnawave

#### 📦 Plans
- Create, edit, delete plans
- Enable / disable a plan
- Per-plan statistics

#### 🎟 Promo Codes
- List, search, create, edit, delete

#### 💳 Payment Gateways
- Configure each gateway (API keys, fees, default currency)
- Test a gateway
- Manage display order in user menu

#### 📊 Statistics
- 5 pages: Remnawave, Users, Transactions, Payments, Plans

#### 📋 Logs
- View events: transactions, purchases, blocks
- Export log to file

#### ⚙️ Features
- Toggle modules: balance, transfers, extra devices, community, agreement

#### 🏷️ Global Discount
- Percentage or fixed discount on all plans
- Scope: subscriptions / extra devices / transfer fees
- Mode: maximum / stacked

#### 💱 Exchange Rates
- Manual or automatic rate
- Base currency: RUB / USD / EUR

#### 🔔 Notifications
- Fine-tune every user and system notification

#### 📥 Import
- Import users from Remnawave Panel or X-UI 3

#### 🤖 Bot Management
- Check for updates and one-click update
- Restart bot
- Mirror bots

</details>

<details>
<summary>🧰 Server Control Panel (`rs`)</summary>

<br>

```bash
rs   # or: remnasale
```

| Action | Description |
|--------|-------------|
| 🔄 Update | Check and install updates from GitHub |
| ℹ️ View logs | Archived container logs |
| 📊 Live logs | Real-time output (Ctrl+C to exit) |
| 🔃 Restart bot | Restart Docker containers |
| 🔃 Restart with logs | Restart + live log output |
| ⬆️ Start bot | Start stopped bot |
| ⬇️ Stop bot | Stop all containers |
| 💾 Database | Save/restore DB, auto-backup to Telegram |
| 🔄 Reinstall | Full reinstall preserving data |
| ⚙️ Edit settings | Edit `.env` configuration |
| 🧹 Clear data | Reset bot data |
| 🗑️ Remove bot | Full removal |

</details>

</details>

---

## 📋 Requirements

<details>
<summary>Show details</summary>

<br>

| Component | Requirements |
|-----------|--------------|
| **OS** | Ubuntu 22.04 / 24.04, Debian 11 / 12 |
| **RAM** | from 1 GB (2 GB recommended) |
| **Domain** | A-record pointing to server IP |
| **Port** | 443 (HTTPS) — port 80 is opened automatically only during certificate issuance/renewal |
| **Remnawave** | Version 2.5.24+, admin API token |
| **Telegram Bot** | Token from @BotFather |

</details>

---

## 💰 Support the Project

<details>
<summary>Show details</summary>

<br>

If the project has been useful, you can support development:

| Method | Details |
|--------|---------|
| **USDT (TRC-20)** | `THqJQsgbWY7Tw1BxdLA6SQAkBGVmMhzeLZ` |
| **BTC (BEP-20)** | `0x657685922d7a9c50e3e90cae3ba9905985349fbb` |
| **YooMoney** | `4100118836481809` |

❤️ Thank you for your support!

</details>

---

## 🔧 Troubleshooting

<details>
<summary>Show details</summary>

<br>

### Make sure that:

> ✅ Domain correctly points to server IP via **A-record**  
> ✅ **Bot token** is valid and active (check in @BotFather)  
> ✅ **Payments Provider** is connected for Telegram Stars  
> ✅ **Remnawave API token** has admin rights  
> ✅ **Remnawave panel URL** is reachable from the bot server  
> ✅ Port **443** is free and not used by other services  

### How to diagnose:

> 📜 Check logs: `rs` → `ℹ️ View logs`  
> 🔄 Restart bot: `rs` → `🔃 Restart bot`  
> ⚙️ Check `.env`: `rs` → `⚙️ Edit settings`  
> 🆘 If nothing helps — open an **Issue** on GitHub with logs  

</details>

---

## ❤️ Credits

The bot was built with a focus on functionality, security and ease of use.  
Thanks to everyone who helps test and improve the system.

---

## 📜 License

Proprietary software. All rights reserved.

---

<p align="center">
  <b>⭐ Give us a star if the project was helpful!</b>
</p>

# ZShare T4

**Weapon sharing for World at War Zombies (Plutonium T4)**

by Xep

[**Download the latest release**](https://github.com/Xeptix/ZShareT4/releases/latest)

Trade guns with a teammate, hand them points, give away a box hit you don't want, and pay
for a teammate's perk, spin or Pack-a-Punch. All of it from the use button, with prompts
that read like the game's own.

- Look at a teammate and press **use** to trade weapons. Ammo goes with the gun, the
  rifle grenade underneath it included.
- **Crouch** first and the same press gives them 1000 points instead.
- Crouch and press use at the **box** while the weapon you paid for is up, and anyone can
  take it. The same at the **Pack-a-Punch** on Der Riese.
- Crouch and press use at a **perk machine**, or at the box or the Pack-a-Punch while
  nobody is using it, and the next teammate to use it pays nothing.

This is the World at War port of [ZShare](https://github.com/Xeptix/ZShare). Every port has
the same settings, with the same names, defaults and meanings.

---

## Requirements

Plutonium T4 (World at War), zombies. No other mods or dependencies.

**Only the host needs this file.** Every part of ZShare runs on the host and reaches
everyone else as ordinary server-to-client traffic — the prompts, the swap, the box, the
machines, the points, the sounds. Players joining your game install nothing.

Works on all four maps. Nacht der Untoten has no perk machines and no Pack-a-Punch, so
there is nothing to pay for there beyond the box; the Pack-a-Punch is Der Riese's alone.

---

## Install

Copy the **`Plutonium`** folder from the download into:

```
%localappdata%
```

It mirrors your existing `%localappdata%\Plutonium` exactly, so Windows will ask whether
to merge — say yes. The only thing it replaces is an older `zshare.gsc`.

That puts the file here:

```
%localappdata%\Plutonium\storage\t4\raw\scripts\sp\zshare.gsc
```

World at War zombies runs on the singleplayer script tree, which is why the folder is `sp`.

### Or run the installer

The download has an **`installer`** folder, one for each system:

```
installer\windows\install.bat
installer/linux/install.sh
```

Each one finds Plutonium's folder, shows you what it is about to copy, and asks once. On
Linux, `install.sh` looks where Plutonium ends up under Wine or Proton — Steam's
`compatdata` including a Steam Deck's, Heroic, Lutris, Bottles, plain `~/.wine`, and the
Flatpak version of each. `install.bat -Yes` and `install.sh --yes` copy without asking, `-Uninstall` / `--uninstall`
removes what an install put there, and `-Find` / `--find` only shows what it detects.

On a Steam Deck, switch to Desktop Mode and double-click
**`installer/linux/Install ZShare.desktop`**. KDE will not run a desktop entry until you
allow it once: right-click it, **Properties** → **Permissions** → tick **Is executable**.

It's optional. Dragging the `Plutonium` folder across yourself is identical.

You don't need to restart the game to load a script — just end the current game and start
a new one.

---

## Usage

Every action is a prompt on screen, the same kind the game shows at a door or a wall buy.
What a prompt says is what a press of **use** will do.

| Prompt | When you see it | What the press does |
|---|---|---|
| `Hold USE to trade weapons` | Looking at a teammate | Offers them the weapon in your hands |
| `Hold USE to accept the trade` | Looking at a teammate who offered you a trade | Swaps their offered weapon for the one you're holding |
| `Hold USE to cancel the trade` | Looking at the teammate you offered a trade to | Withdraws the offer |
| `Hold USE to give 1000 points` | **Crouched**, looking at a teammate | Gives them 1000 points |
| `Hold USE to thank them (100 points)` | **Crouched**, looking at someone who just did you a good turn | Sends them 100 of your points |
| `Hold USE to share this weapon` | **Crouched** at the box or the Pack-a-Punch, with the weapon you paid for waiting | Lets anyone take it |
| `Hold USE to buy this perk for a teammate [Cost: 2500]` | **Crouched** at a perk machine | Pays for the next drink from it |
| `Hold USE to buy a spin for a teammate [Cost: 950]` | **Crouched** at the box while nobody is using it | Pays for the next spin |
| `Hold USE to buy a Pack-a-Punch for a teammate [Cost: 5000]` | **Crouched** at the Pack-a-Punch while nobody is using it | Pays for the next pack |
| `Hold USE to take back your payment` | **Crouched** at a machine you paid for | Gives you your points back |
| `Hold USE for a free spin` | At a box a teammate paid for | Spins it, and it costs you nothing |
| `Hold USE for a free perk` | At a perk machine a teammate paid for | Drinks it, and it costs you nothing |
| `Hold USE for a free Pack-a-Punch` | At the Pack-a-Punch a teammate paid for | Packs your weapon, and it costs you nothing |

Crouching is the whole modifier. Stand up and every prompt goes back to what it always was;
crouch and it turns into giving. Nothing else changes about how you play.

A few chat words, for when you've already walked away:

| Action | Input |
|---|---|
| Share the box hit or Pack-a-Punch you paid for | type `!share` |
| Thank whoever just did you a good turn | **Crouch**, look at them, press **use** — or type `!thank` |
| Send any amount of points | type `!tip 500`, or `!tip <name> 500` |

---

## Trading

What you offer is **the weapon in your hands** when you press. Your teammate can see it
there; nothing needs naming. What you get back is **whatever they're holding** when they
accept — so they switch to the gun they want to give before pressing.

An offer stays open for 10 seconds. It lapses on its own if you switch to your other
weapon, if the two of you move more than twice the prompt range apart, or if either of
you goes down. Pressing use on them again withdraws it. Offering to somebody else replaces
it, and both of you are told either way.

**What travels with a gun:** the clip, the reserve ammo, and the rifle grenade underneath
it with its own ammo. It arrives as the same weapon that left.

**What can't be traded:** grenades, the knife, the bouncing betty, the molotov and the
monkey, and the syrette — each has its own slot and its own rules.

**Same gun twice.** A trade that would leave someone holding a gun they already carry is
refused. On Der Riese that covers the Pack-a-Punched version of it too.

---

## Sharing a box hit

You pay, the weapon rises, and for twelve seconds it's yours to take. **Crouch and press
use** at the box and it's everyone's: the box opens to the whole room, and whoever presses
use takes it — you included, if nobody's quicker.

## Sharing at the Pack-a-Punch

The same at Der Riese's machine. Crouch and press use while your upgraded weapon is
waiting, and anyone can take it. Whoever does gets it exactly as the machine would have
handed it to you.

## Giving points

Crouch, look at a teammate, press use: 1000 points move from you to them, with the game's
own points sound and score popup on both sides. Each press is one gift, a second apart, so
three presses is 3000. You need the points to give them.

---

## Paying for a teammate

Crouch at a perk machine, or at the box or the Pack-a-Punch while nobody is using it, and
the prompt turns into an offer to pay for a teammate. Press use and you pay the machine's
price. From then on the next teammate to walk up reads **`Hold USE for a free ...`**, and
using it costs them nothing — a drink from a perk machine, a spin from the box, a pack
from the Pack-a-Punch. Everybody hears about it, and whoever paid is told who used it.

One payment waits at a machine at a time. While yours is waiting, crouch at the machine
again and the prompt offers your points back. If you don't own that perk yourself, you can
stand up and drink it too.

Paying at the box and at the Pack-a-Punch is the other half of sharing there. Before
anybody uses the machine, a crouched press pays for the next use; while your weapon is
waiting in it, the same press gives the weapon away. The two never overlap, because the
machine can't be used while it spins or upgrades.

| When | What happens |
|---|---|
| A paid spin turns up the teddy bear | The game refunds whoever spun; ZShare moves those points to whoever paid |
| The box moves | The payment waits for the box wherever it lands |
| The machine refuses the press | Your teammate's points go straight back, and the payment is still waiting |
| You're playing solo | There's nobody to pay for, so the prompt never appears |

Stand up and every machine works exactly as it always has.

## The perk limit

`zs_perk_limit` sets how many perks a player can hold. World at War has no limit of its
own — every map with perks has exactly four machines — so `0`, the default, and `-1` both
mean four. Any smaller number is a limit ZShare keeps itself: a player already holding
that many is shown no machine, and no teammate can buy them another.

---

## Configuration

Every setting is at the top of the file under `zs_load_config()`, and each one is also a
dvar of the same name. The script creates each dvar with its default on load, so you can
set them straight from the console:

```bash
zs_points_amount 500
```

The config is re-read every five seconds while the game runs, and again on every press,
so a change takes effect **almost straight away** — no map restart needed. Anything
already set in your config before the map loads is left alone.

`set zs_config_print 1` in the console prints every setting that isn't at its default to
the host's screen, then puts the switch back so it can be used again.

| Dvar | Default | What it does |
|---|---|---|
| `zs_debug` | `0` | Print what the script decides and why, to the first player's screen. |
| `zs_trade` | `1` | Trade weapons with a teammate. |
| `zs_trade_offer_time` | `10` | Seconds an offer stays open. |
| `zs_trade_upgraded` | `1` | Pack-a-Punched weapons can be traded. Off, and the prompt says so when you try. |
| `zs_range` | `64` | How close you have to be for the prompt to appear, in units. An offer lapses at twice this. |
| `zs_points` | `1` | Crouch and press use on a teammate to give them points. |
| `zs_points_amount` | `1000` | How many points one press gives. |
| `zs_points_cooldown` | `1` | Seconds between gifts from one player. |
| `zs_thank` | `1` | Thank whoever did you a good turn, and the `!tip` word. |
| `zs_thank_amount` | `100` | What one thank sends. Comes out of your own points. |
| `zs_thank_time` | `30` | How long a good turn stays thankable, in seconds. |
| `zs_box_share` | `1` | Crouch and press use at the box to share the weapon you paid for. |
| `zs_pap_share` | `1` | The same at the Pack-a-Punch. |
| `zs_perk_pay` | `1` | Crouch and press use at a perk machine to pay for a teammate's drink. Off stops new payments; one already waiting still works and can still be taken back. |
| `zs_box_pay` | `1` | The same at the box, for the next spin. |
| `zs_pap_pay` | `1` | The same at the Pack-a-Punch, for the next pack. |
| `zs_perk_limit` | `0` | How many perks a player can hold. `0` and `-1` are the game's four machines; a smaller number is a limit ZShare keeps. See [The perk limit](#the-perk-limit). |
| `zs_show_hint` | `1` | Tell players what the prompts do, once, shortly after they spawn. |
| `zs_messages` | `1` | The one-line messages — who traded with whom, who shared or paid for what, who gave points. Off leaves the prompts and the sounds. |
| `zs_offer_sound` | `powerup_grabbed` | Played to the player an offer is made to. `none` = silent. |
| `zs_trade_sound` | `weapon_show` | Played to both players when a trade goes through. `none` = silent. |
| `zs_share_sound` | `powerup_grabbed` | Played to everyone else when a weapon is shared or a machine is paid for. `none` = silent. |
| `zs_points_sound` | `cha_ching` | Played when points are given, paid or handed back. `none` = silent. |
| `zs_deny_sound` | `no_purchase` | Played when a press can't do what the prompt said — not enough points, a weapon that can't be traded. `none` = silent. |

### Sounds

All five are stock aliases, so the script stays a single drop-in file. A custom sound
would have to be installed by **every player** rather than just the host, so ZShare uses
the game's own audio instead.

The defaults are what the game itself uses them for: `cha_ching` is the points sound behind
every purchase, `no_purchase` its refusal, and `powerup_grabbed` the ping when a drop is
taken. Other aliases worth trying, all played by the common zombies scripts and so present
on every map:

| Alias | What it is |
|---|---|
| `purchase` | A wall buy going through. |
| `box_poof` | The magic box vanishing. |
| `deny` | A machine's refusal. |
| `perks_power_on` | Power reaching the perk machines. |

Swap one in from the console, or silence one with `none`:

```bash
zs_trade_sound box_poof
```

---

## How this port differs

The same features with the same settings as every other port, allowing for what World at
War gives a script:

- **The prompts name the button, not your key.** Every other port writes the use key into
  the prompt and the game draws whichever key you've bound. This engine prints the token
  as written instead, so ZShare's prompts say `USE`.
- **No mod packaging.** Plutonium's Mods menu is Black Ops II only, so this port has no mod
  copy and none of the two settings that choose between the copies.
- **Nacht der Untoten has no machines** beyond the box, and the Pack-a-Punch is Der Riese's
  alone, so the paying prompts only appear where there is something to pay for.
- **The box is opened to the room rather than marked.** Black Ops has a state that means
  "anyone may take this" and World at War has none, so a shared weapon is handed to
  whoever presses next by ZShare itself.
- **A paid use is a refund, not a discount.** No machine here can be made free, so the
  player using it is given the price the moment they press and the machine charges them
  for it as usual. What they see is the same: it costs them nothing.
- **`none` silences a sound.** An empty dvar can't be set from in game on this engine.

---

## How it works

**The prompts on players are radius triggers.** This game has no use trigger a script can
spawn, so each prompt is a trigger of the kind the revive prompt uses, linked to the
teammate so it follows them, and shown to exactly one player. The press is read by
watching the use button while you're inside it and looking at them — again, the way
reviving works.

**A weapon changes hands piece by piece.** World at War has no helper that reads a weapon
whole and no name that ties a rifle grenade to the gun it hangs under, so ZShare reads the
ammo of everything you carry, takes the gun, and sees what left with it. That is the
launcher, and its ammo is put back on the other side.

**The box is watched rather than replaced.** Stock keeps the buyer in a local variable, so
ZShare follows each box itself: who pressed last before the weapon came up. Sharing hands
the waiting weapon to the next player who presses, then closes the box's own loop exactly
as its twelve-second timeout closes it.

**A machine's prompt is a second trigger.** A machine carries one hint for everybody, so a
payer and a taker standing at the same machine would read the same words. ZShare puts its
own trigger beside each one, shown to a single player at a time, and steps the machine's
own prompt aside for whoever is reading it.

**Perk machines decide who sees them in a small loop of their own**, and ZShare replaces
that loop with a copy: everything stock decided, plus stepping aside for a crouched payer
and for anybody at the limit `zs_perk_limit` sets.

**Points go through the game's own score helpers**, which draw the popups. A gift doesn't
count as points you earned.

**Every prompt is one of a fixed handful of strings.** Hint strings are configstrings, a
pool that doesn't recycle, so a weapon name or a player name never goes on a prompt. Names
go in the chat line, which isn't one.

---

## Notes

- **Prompts and other prompts.** A teammate standing in front of a door or a machine shares
  the space with it; ZShare's prompt is shown only while you're looking at them, so step
  around them if you get the door.
- **Crouching over a downed teammate** revives them. The pay prompt steps aside for a
  revive, the same way the machine's own prompt does.
- **Downed players** have no prompt and can't accept one. Going down lapses an open offer
  in either direction.
- **The box's twelve seconds** are the same shared or not: sharing doesn't extend them.
- **Shi No Numa's machines move** when the huts open, and the pay prompt moves with them.
- **Custom maps** get all of it, as long as they're built on the stock zombies scripts.

---

## Testing

World at War has no GSC compiler, so ZShare T4 is checked against the stock T4 script trees
instead — all four maps, since every map carries its own copy of the zombies scripts:
every function it calls is a real call a zombies script can reach, and every entity field,
notify, flag and sound alias it borrows exists there.

---

## Ports

| Game | Repo |
|---|---|
| Black Ops 4 (T8) | [ZShareT8](https://github.com/Xeptix/ZShareT8) |
| Black Ops III (T7) | [ZShareT7](https://github.com/Xeptix/ZShareT7) |
| Black Ops II (T6) | [ZShare](https://github.com/Xeptix/ZShare) |
| Black Ops (T5) | [ZShareT5](https://github.com/Xeptix/ZShareT5) |
| World at War (T4) | ZShareT4 — you are here |

Versions are kept in step: the same version number means the same feature set, allowing
for what each engine can actually do.

**All five in one download.** The [Treyarch
Bundle](https://github.com/Xeptix/ZShare/releases/latest) carries every game ZShare runs
on, laid out as each drops in — the `Plutonium` tree for this game and the other two, Black
Ops III's folders, Black Ops 4's mod folder — with one installer that asks which of them to
install.

---

## Changelog

### v1.0

- Initial release.
- **Trade weapons** with a teammate from the use prompt. Ammo and the rifle grenade travel
  with the gun.
- **Give points** with a crouched press of the same prompt. `zs_points_amount` sets how
  many.
- **Share a box hit** or a **Pack-a-Punch** with a crouched press at the machine, or with
  `!share` from chat.
- **Pay for a teammate** at a perk machine, the box or the Pack-a-Punch with a crouched
  press, and take the payment back the same way. `zs_perk_pay`, `zs_box_pay` and
  `zs_pap_pay` switch each one.
- **Thank a teammate** who paid for you, shared a hit or gave you points: for a while the
  crouched prompt on them offers a small thank, or type `!thank`. The points come out of
  your own. `zs_thank_amount` and `zs_thank_time` set how much and how long.
- **Tip any amount** with `!tip 500`, or `!tip <name> 500`.
- **`zs_perk_limit`** — how many perks a player can hold.
- Every setting is a dvar, re-read while the game runs, and `set zs_config_print 1` lists
  the ones you've changed.

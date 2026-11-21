# DEEPHOLD

**An adventure underground, for the UNC 16**
United Northern Computers

---

## The story so far

Nobody remembers who dug Deephold, or why they stopped. What the valley remembers is that
three treasures went down with them and never came up, and that the woodcutter who built
his cabin over the old workings did not stay in it long. He left the door open, and a
chest by the hearth, empty.

You have walked two days to get here. You have a good pair of boots and no lamp. The
cabin is in front of you. There is a letterbox by the path, which is odd, since nobody
has delivered here in a hundred years.

Your task: find the three treasures of Deephold, bring them up, and lay them in the oak
chest. Do that and the valley will call you a Master Delver. Fail, and the valley will
not call you anything, because it will not find you.

## Loading the game

1. Put the cassette in the deck and rewind it.
2. Type `LOAD` and press RETURN. Press PLAY on the deck when the machine asks.
3. When the machine says `READY.`, type `RUN` and press RETURN.

DEEPHOLD needs a UNC 16 and nothing else. It makes no sound, so there is nothing wrong
with your speaker.

## How to play

DEEPHOLD has no pictures. It tells you where you are and what you can see, and then it
shows you a `>` and waits. You type what you want to do, in plain words, and press
RETURN. The game tells you what happened. That is the whole of it.

```
FOREST PATH
TALL PINES CROWD THE PATH, WHICH ENDS
HERE. ONE OLD PINE HAS LOW BRANCHES.
THE CLEARING IS BACK SOUTH.

>EXAMINE TREE
ITS BRANCHES WOULD MAKE A GOOD LADDER.

>_
```

DELETE rubs out the last letter. A command can be up to 31 letters long.

### Talking to the game

The game understands **one or two words**: a verb, and usually the thing you mean.

```
>TAKE LAMP
>OPEN LETTERBOX
>INVENTORY
```

You may dress a command up, and the game will quietly ignore the dressing. `TAKE THE
LAMP`, `LOOK AT THE RUG` and `PUT THE EGG IN THE CHEST` all work, because THE, A, AN, AT,
IN, INTO, TO, WITH, ON, OFF and UNDER are thrown away, and so is anything after the second
word that counts. `KILL TROLL WITH SWORD` means `KILL TROLL`: you fight with what you carry.

The game knows a word by its **first three letters**. `INV` is as good as `INVENTORY`,
and `EXA` as good as `EXAMINE`. (So is `EXAMPLE`. The machine has 16K, and it has spent
it on the caves.)

If it doesn't follow you, it says so, and the turn doesn't count:

| It says | It means |
|---|---|
| `BEG PARDON?` | You pressed RETURN on nothing. |
| `I DON'T KNOW THAT VERB.` | The first word isn't one it knows. Try another way of saying it. |
| `I DON'T KNOW THAT WORD.` | The second word isn't a thing in this game. |
| `YOU'LL HAVE TO SAY WHAT.` | That verb needs a thing: `TAKE` what? |
| `YOU DON'T SEE THAT HERE.` | It knows the thing, but it isn't here, or isn't here yet. |
| `IT'S TOO DARK TO SEE.` | Exactly that. See "Light", below. |

### Moving about

Type a direction. The short forms save a lot of typing.

| Type | Or | To go |
|---|---|---|
| `N` | `NORTH`, `GO NORTH` | north |
| `S` | `SOUTH` | south |
| `E` | `EAST` | east |
| `W` | `WEST` | west |
| `U` | `UP`, `CLIMB` | up |
| `D` | `DOWN`, `CLIMB DOWN` | down |

Each place's description says which ways lead out of it, usually. `YOU CAN'T GO THAT WAY.`
costs you a move and nothing else.

### The words it knows

| Verb | Also | What it does |
|---|---|---|
| `LOOK` | `L` | Describes where you are again. |
| `EXAMINE` *thing* | `X`, `LOOK AT` | Looks closely at something. Do this often. |
| `INVENTORY` | `I` | Lists what you are carrying. |
| `TAKE` *thing* | `GET`, `PICK UP` | Picks something up. |
| `DROP` *thing* | `PUT` | Puts something down. In the cabin, a treasure goes into the chest. |
| `OPEN` *thing* | `UNLOCK` | Opens something, if you have what it takes. |
| `MOVE` *thing* | `PULL`, `PUSH`, `LIFT` | Shifts something that is too big to take. |
| `READ` *thing* | | Reads it. |
| `LIGHT LAMP` | `TURN ON LAMP` | Lights the lamp. |
| `EXTINGUISH LAMP` | `DOUSE`, `TURN OFF LAMP` | Puts it out. |
| `KILL` *thing* | `ATTACK`, `FIGHT`, `HIT` | Starts, or carries on, a fight. |
| `JUMP` | | Jumps. Think first. |
| `WAIT` | `Z` | Lets a move go by. |
| `SCORE` | | Your points, your moves, and what the chest holds. |
| `HELP` | | A reminder of all this. |
| `QUIT` | `Q` | Gives up, with your score. |

There are a few more that the game will not tell you about. Adventurers have always
tried saying odd things in odd places.

## Light

Under the cabin it is dark, and the dark in Deephold is not empty. If you find yourself
somewhere with no light, the game will tell you what you can hear. **You have one move.**
Go back the way you came, or light something. There is no second warning.

The lamp burns for about 150 moves, and only while it is lit. `EXAMINE LAMP` tells you
how much is left, and it warns you once when it is low. Put it out when you are above
ground. A lamp lights the place it is in whether you are holding it or not, which is
worth knowing and can also be how you lose it.

## Fighting

Not everything down there wants you to pass. A fight goes blow by blow: type `KILL` and
the creature's name for each one. Some blows land, some are parried, and some are the
creature's. You can take one wound. You cannot take two.

Bare hands impress nobody.

## Scoring

There are 100 points to be had. Most of them are for treasures **in the chest**: carrying
one about earns nothing. The rest is for getting past what stands in your way.

When the game ends, one way or another, it gives you a rank.

| Rank | For |
|---|---|
| Troll Fodder | Dying with little to show for it |
| Journeyman Delver | Dying with a fair start made |
| Master Delver | All three treasures home |

A Master's game also counts its moves. Under fifty is good. There is no way to save a
game: Deephold is small enough to do in one sitting, once you know how, and finding out
how is the game.

## Advice to new adventurers

1. **Draw a map.** A box for each place, a line for each way out, with its direction.
   You will want it in the tunnels.
2. **Examine everything.** A thing that is described oddly is described oddly on purpose.
3. **Read what you find.** People who leave notes usually have a reason.
4. **Take everything that will come.** You can carry all of it, and you will not know
   what it was for until you need it.
5. **Where every tunnel looks the same**, make them different. You are carrying things.
   Things can be put down.
6. **If one way of saying it fails, try another.** `PULL` where `MOVE` seems wrong,
   `UNLOCK` where `OPEN` does.
7. **Dying is part of it.** Type `Y` and go again. You will be quicker this time.

## Three sealed hints

Read these only when you are properly stuck. They are in order: the first for those who
cannot get under the cabin, the last for those who nearly have it all.

<details>
<summary>1. There seems to be no way down.</summary>

The cabin's floor is not all on show. `EXAMINE RUG`, and then do something about it.
What you find underneath is shut.
</details>

<details>
<summary>2. Something will not let me cross.</summary>

It will not be talked round, and it laughs at empty hands. There was something sharp in
the cabin. Take it, and be ready to try more than once.
</details>

<details>
<summary>3. I have found a box I cannot open.</summary>

Someone came for it before you, got lost in the tunnels east of the cellar, and still has
what you need. From the cellar: east, south, east.
</details>

## If something goes wrong

**The game stops with `BREAK IN` and a number.** You pressed STOP. Type `RUN` to start
again from the clearing.

**The screen fills up.** It scrolls, as BASIC does. `LOOK` brings the description back.

**You want to see how it works.** Press STOP and type `LIST`. DEEPHOLD is 200 lines of
UNC BASIC, and BASIC has no words, only numbers, so the whole game is done with
arithmetic. The notes at the top of the listing say how. Reading it is cheating, and
is encouraged.

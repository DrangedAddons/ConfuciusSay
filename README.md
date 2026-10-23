# ConfuciusSay

A World of Warcraft addon for WoW Forever (and the Classic beta). On a character whose name contains "confucius", anyone who whispers you "confucius" gets a random Confucius say whispered back:

> Confucius say, man who run behind bus get exhausted

## Features
- **124 sayings built in:** the pun kind, not the real ones. 61 are tagged rude; filter on Rude or Clean to switch whole groups on or off.
- **Your list:** turn each saying on or off, add your own, edit or remove any. Removed defaults can be put back with Restore defaults.
- **Keywords:** comma-separated, any case, anywhere in the message.
- **Guild, party and raid chat (off by default):** each can use the default keywords or its own, and post the reply in that chat or whisper it to the sender.
- **No repeats** until every active saying has been used. Per-player and group-chat cooldowns, and a short delay before replying.
- Never answers its own messages or another ConfuciusSay's saying, so two players running it can't loop.

## Using it
- `/csay` (or `/confuciussay`), the minimap button, the addon list button or Options > AddOns > ConfuciusSay opens the settings.
- `/csay test` prints a random saying in your chat (only you see it).
- `/csay on` / `/csay off`.
- Which characters reply is set on the General tab ("Only on characters whose name contains"). Empty means every character.

Settings and sayings are account-wide, so every Confucius alt shares the list.

Sayings p1-p100 are from the collection at trees-and-lambdas.info/matushansky. Icon: ui_chat (Wowhead icon 2056011), scaled up by `tools/make_icon.py`.

Includes LibStub, CallbackHandler, LibDataBroker and LibDBIcon (see Libs).

# Changelog

## 1.0.0
- First live release for WoW Forever. The addon is now listed for Forever only (the Classic beta has ended). No changes in game.

## 0.4.2
- **/cs r** works again: ConfuciusSay now remembers who whispered you last (in-game or Battle.net) itself, instead of asking the game, which said nobody had. Works with WIM.

## 0.4.1
- **/cs in a WIM window** now sends to that window: the whisper (or Battle.net whisper) you're in, or WIM's guild/party/raid/channel window. Before, WIM passed /cs to the main chat box, which was on /say.

## 0.4.0
- **/cs** posts a random saying whenever you like, to the chat you're typing in: say, yell, party, guild, officer, raid, instance, General/Trade or any numbered channel, a whisper or a Battle.net whisper (so `/r` then `/cs` replies). Works on any character, no keyword or cooldown.
- `/cs g`, `/cs p`, `/cs raid`, `/cs s`, `/cs 2` (channel number), `/cs r` (reply to your last whisper) pick the chat instead.
- Key binding "Send a saying to your current chat" (Options > Keybindings > AddOns > ConfuciusSay): sends to the last chat you typed in.

## 0.3.0
- **Battle.net whispers** trigger replies too, on by default with the default keywords. The reply goes back as a Battle.net whisper. Switch it off or give it its own keywords on the Triggers tab.

## 0.2.0
- **Add many...** on the Sayings tab: paste or type a block of sayings, one per line, and add them all at once. A leading "Confucius say," on a line is dropped (replies add it), and blank lines and sayings already in the list are skipped. The list then shows "Added by me" with the new ones at the bottom.

## 0.1.0
- First version. On a character whose name contains "confucius", a whisper containing a keyword (default "confucius") gets a random Confucius say whispered back.
- 124 sayings built in: the 100 from trees-and-lambdas.info (61 tagged rude), plus WoW and clean ones. A shuffled deck, so nobody hears a repeat until the list has gone round.
- Settings window (/csay, minimap button, addon list button, Options > AddOns):
  - **Sayings:** the whole list with an on/off box per saying, filters (All, Active, Inactive, Rude, Clean, Added by me), search, add, edit, remove, tag as rude, activate/deactivate everything shown, restore removed defaults, test.
  - **Triggers:** default keywords; whispers, guild, party and raid chat each switch on separately, use the default keywords or their own, and post the reply in that chat or whisper it to the sender.
  - **General:** on/off, the character name filter, reply prefix, reply delay, per-player and group-chat cooldowns, minimap button.
- Never replies to itself or to a message that already holds one of the sayings, so two players running it can't loop.
- Icon: Wowhead's ui_chat (2056011) scaled to 64x64.

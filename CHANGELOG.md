# Changelog

## 0.1.0
- First version. On a character whose name contains "confucius", a whisper containing a keyword (default "confucius") gets a random Confucius say whispered back.
- 124 sayings built in: the 100 from trees-and-lambdas.info (61 tagged rude), plus WoW and clean ones. A shuffled deck, so nobody hears a repeat until the list has gone round.
- Settings window (/csay, minimap button, addon list button, Options > AddOns):
  - **Sayings:** the whole list with an on/off box per saying, filters (All, Active, Inactive, Rude, Clean, Added by me), search, add, edit, remove, tag as rude, activate/deactivate everything shown, restore removed defaults, test.
  - **Triggers:** default keywords; whispers, guild, party and raid chat each switch on separately, use the default keywords or their own, and post the reply in that chat or whisper it to the sender.
  - **General:** on/off, the character name filter, reply prefix, reply delay, per-player and group-chat cooldowns, minimap button.
- Never replies to itself or to a message that already holds one of the sayings, so two players running it can't loop.
- Icon: Wowhead's ui_chat (2056011) scaled to 64x64.

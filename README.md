Bottle o' Jelly
=====

Jelly is an experimental framework built on top, with, over and sometimes under the official Stonehearth modding API. Its spiritual predecessor was RP, whose code is the base for Jelly.

# What can Jelly do?

Jelly itself does nothing. It is merely a library that can be used by mod authors to make their life easier or to coordinate multiple mods accessing the same resources. It has multiple parts to achieve that.

## `jelly.mod`

`jelly.mod` is a class that can be inherited from in your own mods. It's a scaffolding tool, that means that mod authors can inherit from it to quickly build simple mods - including configuration, dependencies and sometimes simply convenience.

## Extended libraries

Jelly adds new libraries that make your life easier. `jelly.timers` contains several functions dedicated to timing, whereas `jelly.util` provides several functions for convenience. `jelly.resources` deals with some nastier resources and `jelly.linq` is an experimental library to bring .NET's LINQ functionality to lua.

## New data sources
lua is a powerful tool - and a complicated one. Stonehearth aims to separate script ("controller") and data ("models") by storing data in JSON files. That support is still incomplete - that's where Jelly comes in handy.

Jelly overrides functions and complete classes to add model functionality. An example would be the world generation, where `jelly:index:trees` and `jelly:index:tree_templates` together form a way mod authors can change the placement of trees.

## New events
For those who wish to wield a mightier sword, Jelly adds new events into the existing code. This includes both simple information events about things happening as well as queries - where multiple mods can either change directly or propose changes.

## Somewhat documented.

Jelly's API is documented - in the code. Preparations to have something create Wiki pages for that are already in progress.

# Terms and Conditions: The Royal Jelly

Jelly is a community made, inofficial project. There are several things you should keep in mind while using Jelly.

## Jelly is a parachute, not a safety net.

- It's possible that Jelly breaks with every update. It might take a few hours up to a few days to get a new version running.
- Things can break. Things *will* break. Jelly is just as much of an Alpha construct as the game itself. While the goal will be to minimize damage, it cannot be guaranteed. Prepare to have your mod rustled.

## Jelly is alive.

- Jelly will adapt. Depending on current needs and recent changes in the official API, Jelly will change. Most of the time, the backwards compatibility can be kept - but it's no guarantee.
- Changes will be communicated. If an update, be it Stonehearth or Jelly, breaks something, you will be informed about it. This might not happen in advance and as usual takes some time but the idea is that you get changelogs that include workarounds or fixes for current code.
- Jelly isn't built to last. Jelly will disappear. The further the official API progresses, the smaller Jelly will become. If a Jelly feature is implemented in the official API, Jelly will first redirect to that feature and deprecate itself. After some time, that feature will be removed from Jelly completely.

## Jelly is autonomous.

- Jelly deals with overrides. Jelly deals with monkey patching, hacking, hotfixing and all that stuff. Ideally you don't need to do any of these things in your mod to get running. This allows you to worry less about updates - and more about your mod.
- It's doing a lot of magic that you as player or mod author may not be aware of. It may change how the game itself (internally) behaves - which can break mods that are not aware of such changes and are not using Jelly themselves. This is likely not going to be a problem, but it could be one.
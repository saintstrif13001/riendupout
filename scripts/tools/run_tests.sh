#!/usr/bin/env bash
# Lance la campagne de tests de capture.gd et signale tout echec.
#
# Pourquoi ce script existe : les campagnes etaient lancees a la main avec un
# grep sur "^TEST_RESULT ... all_ok=false". Trois pieges ont laisse des tests
# invisibles pendant longtemps :
#   1. certains tests n'imprimaient aucune ligne "TEST_RESULT" (uniquement des
#      diagnostics a lire a l'oeil) : ils ne pouvaient jamais etre juges ;
#   2. deux tests ont besoin de Main.tscn et etaient lances contre World.tscn,
#      donc echouaient systematiquement pour une mauvaise raison ;
#   3. les tests qui attendent des minuteurs REELS ont besoin d'un budget de
#      frames large ; avec la valeur par defaut ils sortaient avant d'imprimer
#      leur resultat, sans bruit.
# Tout test qui n'imprime pas "all_ok=" est desormais signale comme MUET, au
# meme titre qu'un echec : un test qu'on ne peut pas juger n'est pas un test.
#
# Usage :  scripts/tools/run_tests.sh [regex-de-filtre]
#   ex.    scripts/tools/run_tests.sh '^test_[a-f]'

set -u
GODOT="${GODOT:-/c/Users/jarch/Documents/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe}"
CAPTURE="scripts/tools/capture.gd"
FILTER="${1:-.}"
# Budget de frames large : les tests qui attendent des minuteurs reels
# (animations, fondus audio, transitions de lumiere) sortaient sinon avant
# d'avoir imprime leur verdict.
FRAMES=600
# Tests qui pilotent le MENU et non le monde : ils ont besoin de Main.tscn.
MAIN_SCENE_TESTS=" test_char_portraits test_options_screen test_continue_menu "

modes=$(grep -oE 'test_mode == "test_[a-z0-9_]+"' "$CAPTURE" | sed 's/.*"\(test_[a-z0-9_]*\)"/\1/' | sort -u | grep -E "$FILTER")
fail=0
count=0
for t in $modes; do
	count=$((count + 1))
	scene="res://scenes/World.tscn"
	case "$MAIN_SCENE_TESTS" in *" $t "*) scene="res://scenes/Main.tscn";; esac
	out=$(timeout 90 "$GODOT" --path . --headless --script "$CAPTURE" -- "$scene" user://screenshot.png "$FRAMES" none "$t" 2>&1)
	verdict=$(printf '%s' "$out" | grep -E "^TEST_RESULT" | grep -oE "all_ok=(true|false)" | head -1)
	if printf '%s' "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
		printf 'ERREUR  %-28s %s\n' "$t" "$(printf '%s' "$out" | grep -E 'SCRIPT ERROR|Parse Error' | head -1 | cut -c1-110)"
		fail=$((fail + 1))
	elif [ -z "$verdict" ]; then
		printf 'MUET    %-28s (aucun "all_ok=" imprime)\n' "$t"
		fail=$((fail + 1))
	elif [ "$verdict" = "all_ok=false" ]; then
		printf 'ECHEC   %-28s %s\n' "$t" "$(printf '%s' "$out" | grep -E '^TEST_RESULT' | head -1 | cut -c1-130)"
		fail=$((fail + 1))
	fi
done
printf '%d tests, %d probleme(s)\n' "$count" "$fail"
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)

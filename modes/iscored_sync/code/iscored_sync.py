from mpf.core.mode import Mode

import json
import os
import threading
import time
import urllib.parse
import urllib.request


# ------------------------------------------------------------
# iSCORED SETTINGS
# ------------------------------------------------------------
# Your iScored gameroom/game:
# Gameroom: FT1
# Game: DIE HARD TRILOGY
#
# Using the documented game-name endpoint rather than GameID.
# ------------------------------------------------------------
ISCORED_GAME_URL = "https://www.iscored.info/api/FT1/DIE%20HARD%20TRILOGY"
ISCORED_SUBMIT_URL = "https://www.iscored.info/api/FT1/DIE%20HARD%20TRILOGY/submitScore"

DEFAULT_PLAYER_NAME = "JohnMcClane"
QUEUE_FILE_NAME = "iscored_queue.json"
CACHE_FILE_NAME = "iscored_cache.json"
RECORDS_FILE_NAME = "machine_records.json"

TOP_N = 10
HTTP_TIMEOUT = 2


class IscoredSync(Mode):

    # ------------------------------------------------------------
    # MODE START
    # Registers iScored leaderboard and local machine record events.
    #
    # IMPORTANT:
    # Do not flush queued scores during boot.
    # Keeps MPF startup safe even with no internet.
    # ------------------------------------------------------------
    def mode_start(self, **kwargs):

        self.info_log("iScored integration loaded")

        self._queue_lock = threading.Lock()
        self._refresh_lock = threading.Lock()
        self._cache_lock = threading.Lock()
        self._records_lock = threading.Lock()

        self._pending_records = self._default_pending_records()

        self.machine.events.add_handler(
            "iscored_submit_score",
            self.submit_score
        )

        self.machine.events.add_handler(
            "iscored_flush_queue",
            self.flush_queue
        )

        self.machine.events.add_handler(
            "iscored_refresh_scores",
            self.refresh_scores
        )

        self.machine.events.add_handler(
            "mode_attract_started",
            self.refresh_scores
        )

        # Manual/test record events.
        # Later we will wire real loop, multiball, and villain events into these.
        self.machine.events.add_handler(
            "record_save_loop_champion",
            self.record_save_loop_champion
        )

        self.machine.events.add_handler(
            "record_save_multiball_hero",
            self.record_save_multiball_hero
        )

        self.machine.events.add_handler(
            "record_save_villain_mvp",
            self.record_save_villain_mvp
        )

        self.machine.events.add_handler(
            "record_refresh_machine_records",
            self.refresh_machine_records
        )

        # Pending machine record events.
        # These collect values during the game, then save them
        # with the same initials/name used for the normal high score.
        self.machine.events.add_handler(
            "record_candidate_loop_champion",
            self.record_candidate_loop_champion
        )

        self.machine.events.add_handler(
            "record_candidate_multiball_hero",
            self.record_candidate_multiball_hero
        )

        self.machine.events.add_handler(
            "record_candidate_villain_mvp",
            self.record_candidate_villain_mvp
        )

        self.machine.events.add_handler(
            "record_apply_pending_records",
            self.record_apply_pending_records
        )

        self.machine.events.add_handler(
            "record_clear_pending_records",
            self.record_clear_pending_records
        )

        self.machine.events.add_handler(
            "text_input_high_score_complete",
            self.record_apply_pending_records
        )

        # Apply saved records on boot.
        records = self._load_records()
        self._apply_record_machine_vars(records)

        # Apply any saved local iScored cache straight away.
        # Then the normal attract refresh will try to update from iScored.
        cached_entries = self._load_cache_entries()
        if cached_entries:
            self._apply_leaderboard_machine_vars(cached_entries)

    # ------------------------------------------------------------
    # SUBMIT SCORE
    # Called by event:
    #   iscored_submit_score
    # ------------------------------------------------------------
    def submit_score(self, **kwargs):

        player = self.machine.game.player if self.machine.game else None

        if not player:
            self.warning_log("No player found for iScored submit")
            return

        score = int(player.score)
        player_name = self._get_player_name(player)

        threading.Thread(
            target=self._check_then_submit_or_queue,
            args=(player_name, score),
            daemon=True
        ).start()

    # ------------------------------------------------------------
    # FLUSH QUEUE
    # Called manually by event:
    #   iscored_flush_queue
    # ------------------------------------------------------------
    def flush_queue(self, **kwargs):

        threading.Thread(
            target=self._flush_queue_thread,
            daemon=True
        ).start()

    # ------------------------------------------------------------
    # REFRESH SCORES
    # Called by:
    #   iscored_refresh_scores
    #   mode_attract_started
    # ------------------------------------------------------------
    def refresh_scores(self, **kwargs):

        threading.Thread(
            target=self._refresh_scores_thread,
            daemon=True
        ).start()

    # ------------------------------------------------------------
    # GET PLAYER NAME
    # Tries common MPF player fields, then falls back.
    # ------------------------------------------------------------
    def _get_player_name(self, player):

        player_name = None

        try:
            player_name = getattr(player, "initials", None)
        except Exception:
            player_name = None

        if not player_name:
            try:
                player_name = player["initials"]
            except Exception:
                player_name = None

        if not player_name:
            try:
                player_name = getattr(player, "player_initials", None)
            except Exception:
                player_name = None

        if not player_name:
            try:
                player_name = player["player_initials"]
            except Exception:
                player_name = None

        if not player_name:
            player_name = DEFAULT_PLAYER_NAME

        player_name = str(player_name).strip()

        if not player_name:
            player_name = DEFAULT_PLAYER_NAME

        return player_name[:20]

    # ------------------------------------------------------------
    # CHECK THEN SUBMIT OR QUEUE
    # Checks cached top 10 before posting.
    #
    # Important:
    # The local cached top 10 is now the machine's working copy.
    # If a score qualifies, we insert it locally immediately so
    # attract mode can show it even if internet is down.
    # ------------------------------------------------------------
    def _check_then_submit_or_queue(self, player_name, score):

        qualifies = self._score_qualifies_for_top_ten(score)

        if qualifies is True:

            self.info_log(
                "iScored cached score qualifies for top %s -> player: %s score: %s",
                TOP_N,
                player_name,
                score
            )

            # Add to local cached leaderboard immediately.
            # This makes attract display update even before online sync.
            self._run_on_mpf_thread(
                self._insert_score_into_cache_and_apply,
                player_name,
                score,
                True
            )

            ok = self._post_to_iscored(
                player_name=player_name,
                score=score,
                queue_on_fail=False
            )

            if ok:

                # Give iScored a moment before checking the leaderboard.
                time.sleep(1.0)

                if self._submitted_score_is_visible(player_name, score):

                    self.info_log(
                        "iScored submit verified on leaderboard -> player: %s score: %s",
                        player_name,
                        score
                    )

                    self._refresh_scores_thread()

                else:

                    self.warning_log(
                        "iScored submit said accepted but score is NOT visible, queued -> player: %s score: %s",
                        player_name,
                        score
                    )

                    self._queue_score(player_name, score)
                    self._refresh_scores_thread()

            else:

                self.warning_log(
                    "iScored submit failed, score kept locally and queued -> player: %s score: %s",
                    player_name,
                    score
                )

                self._queue_score(player_name, score)

            return

        if qualifies is False:

            self.info_log(
                "iScored skipped -> score not cached top %s: player: %s score: %s",
                TOP_N,
                player_name,
                score
            )

            return

        # No cache and no online check.
        # Safer arcade behaviour: queue it, but do not overwrite display.
        self.warning_log(
            "iScored could not check cached/online leaderboard, queued for later -> player: %s score: %s",
            player_name,
            score
        )

        self._queue_score(player_name, score)

    # ------------------------------------------------------------
    # VERIFY SUBMITTED SCORE IS REALLY VISIBLE
    # ------------------------------------------------------------
    def _submitted_score_is_visible(self, player_name, score):

        try:
            entries = self._get_leaderboard_entries(TOP_N)

            target_name = str(player_name).strip().lower()
            target_score = int(score)

            for entry in entries:

                entry_name = str(entry.get("name", "")).strip().lower()
                entry_score = int(entry.get("score", 0))

                if entry_name == target_name and entry_score == target_score:
                    return True

            return False

        except Exception as e:

            self.warning_log(
                "iScored submit verify failed: %s",
                e
            )

            return False

    # ------------------------------------------------------------
    # SCORE QUALIFIES CHECK
    # Uses local cached top 10 first.
    # If no cache exists yet, tries online.
    # ------------------------------------------------------------
    def _score_qualifies_for_top_ten(self, score):

        try:

            entries = self._load_cache_entries()

            if not entries:

                self.info_log(
                    "iScored no local cache yet, checking online leaderboard"
                )

                entries = self._get_leaderboard_entries(TOP_N)
                entries = self._normalise_entries(entries)
                self._save_cache_entries(entries)

            scores = []

            for entry in entries:
                try:
                    scores.append(int(entry.get("score", 0)))
                except Exception:
                    scores.append(0)

            while len(scores) < TOP_N:
                scores.append(0)

            scores.sort(reverse=True)

            tenth_score = scores[TOP_N - 1]

            self.info_log(
                "iScored cached top %s cutoff is %s, player score is %s",
                TOP_N,
                tenth_score,
                score
            )

            return int(score) > int(tenth_score)

        except Exception as e:

            self.warning_log("iScored cached leaderboard check failed: %s", e)
            return None

    # ------------------------------------------------------------
    # GET LEADERBOARD ENTRIES FROM iSCORED
    # ------------------------------------------------------------
    def _get_leaderboard_entries(self, max_scores):

        params = urllib.parse.urlencode({
            "max": max_scores
        })

        url = ISCORED_GAME_URL + "?" + params

        request = urllib.request.Request(
            url,
            method="GET",
            headers={
                "User-Agent": "DieHardMPF/1.0"
            }
        )

        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
            body = response.read().decode("utf-8", errors="ignore")

        result = json.loads(body)

        raw_scores = result.get("scores", [])

        entries = []

        for index, entry in enumerate(raw_scores[:max_scores]):

            try:
                score_value = int(entry.get("score", 0))
            except Exception:
                score_value = 0

            name = str(entry.get("name", "---")).strip()
            rank = str(entry.get("rank", index + 1)).strip()

            entries.append({
                "rank": rank,
                "name": name if name else "---",
                "score": score_value,
                "score_text": self._format_score(score_value),
                "pending": False
            })

        return entries

    # ------------------------------------------------------------
    # REFRESH SCORES THREAD
    # Prevents overlapping leaderboard refreshes.
    #
    # Online success:
    #   save online scores into local cache
    #   apply machine vars
    #
    # Online failure:
    #   keep/apply saved local cache
    # ------------------------------------------------------------
    def _refresh_scores_thread(self):

        if not self._refresh_lock.acquire(blocking=False):

            self.info_log("iScored leaderboard refresh already running, skipped")
            return

        try:

            entries = self._get_leaderboard_entries(TOP_N)
            entries = self._normalise_entries(entries)

            self._save_cache_entries(entries)

            self._run_on_mpf_thread(
                self._apply_leaderboard_machine_vars,
                entries
            )

        except Exception as e:

            self.warning_log(
                "iScored leaderboard refresh failed, using local cache: %s",
                e
            )

            cached_entries = self._load_cache_entries()

            if cached_entries:

                self._run_on_mpf_thread(
                    self._apply_leaderboard_machine_vars,
                    cached_entries
                )

            else:

                self.warning_log(
                    "iScored no local cache available yet"
                )

        finally:

            self._refresh_lock.release()

    # ------------------------------------------------------------
    # INSERT SCORE INTO LOCAL CACHE AND APPLY VARS
    # Used when a new score qualifies.
    # ------------------------------------------------------------
    def _insert_score_into_cache_and_apply(self, player_name, score, pending):

        entries = self._load_cache_entries()

        entries.append({
            "rank": "",
            "name": player_name,
            "score": int(score),
            "score_text": self._format_score(score),
            "pending": bool(pending)
        })

        entries = self._normalise_entries(entries)
        self._save_cache_entries(entries)
        self._apply_leaderboard_machine_vars(entries)

        self.info_log(
            "iScored local cache inserted -> player: %s score: %s pending: %s",
            player_name,
            score,
            pending
        )

    # ------------------------------------------------------------
    # NORMALISE ENTRIES
    # Sorts, trims to top 10, fills empty slots.
    # ------------------------------------------------------------
    def _normalise_entries(self, entries):

        clean_entries = []

        for entry in entries:

            try:
                score_value = int(entry.get("score", 0))
            except Exception:
                score_value = 0

            name = str(entry.get("name", "---")).strip()
            if not name:
                name = "---"

            pending = bool(entry.get("pending", False))

            clean_entries.append({
                "rank": "",
                "name": name,
                "score": score_value,
                "score_text": self._format_score(score_value) if score_value > 0 else "---",
                "pending": pending
            })

        clean_entries.sort(
            key=lambda item: int(item.get("score", 0)),
            reverse=True
        )

        clean_entries = clean_entries[:TOP_N]

        while len(clean_entries) < TOP_N:
            clean_entries.append({
                "rank": "",
                "name": "---",
                "score": 0,
                "score_text": "---",
                "pending": False
            })

        for index, entry in enumerate(clean_entries):
            entry["rank"] = str(index + 1)
            entry["score_text"] = self._format_score(entry["score"]) if int(entry["score"]) > 0 else "---"

        return clean_entries

    # ------------------------------------------------------------
    # APPLY LEADERBOARD MACHINE VARS
    #
    # Important:
    # GMC/Godot only receives machine_var events when values change.
    # If the same scores already exist before the attract slide
    # registers its handlers, Godot may only receive iscored_last_update.
    #
    # So we clear display vars first, then apply real values.
    # ------------------------------------------------------------
    def _apply_leaderboard_machine_vars(self, entries):

        entries = self._normalise_entries(entries)

        # Force change events first.
        for index in range(TOP_N):

            slot = index + 1

            self._set_machine_var(
                "iscored_{}_rank".format(slot),
                ""
            )

            self._set_machine_var(
                "iscored_{}_name".format(slot),
                ""
            )

            self._set_machine_var(
                "iscored_{}_score".format(slot),
                -1
            )

            self._set_machine_var(
                "iscored_{}_score_text".format(slot),
                ""
            )

            self._set_machine_var(
                "iscored_{}_pending".format(slot),
                0
            )

        # Apply real values.
        for index in range(TOP_N):

            slot = index + 1
            entry = entries[index]

            self._set_machine_var(
                "iscored_{}_rank".format(slot),
                entry["rank"]
            )

            self._set_machine_var(
                "iscored_{}_name".format(slot),
                entry["name"]
            )

            self._set_machine_var(
                "iscored_{}_score".format(slot),
                entry["score"]
            )

            self._set_machine_var(
                "iscored_{}_score_text".format(slot),
                entry["score_text"]
            )

            self._set_machine_var(
                "iscored_{}_pending".format(slot),
                1 if entry.get("pending", False) else 0
            )

        self._set_machine_var(
            "iscored_last_update",
            int(time.time())
        )

        real_scores = 0

        for entry in entries:
            try:
                if int(entry.get("score", 0)) > 0:
                    real_scores += 1
            except Exception:
                pass

        self.info_log(
            "iScored leaderboard updated -> %s score(s)",
            real_scores
        )

    # ------------------------------------------------------------
    # PENDING RECORD DEFAULTS
    # ------------------------------------------------------------
    def _default_pending_records(self):

        return {
            "loop_champion": 0,
            "multiball_hero": {
                "value": 0,
                "mode": "---"
            },
            "villain_mvp": {
                "value": 0,
                "mode": "---"
            }
        }

    # ------------------------------------------------------------
    # PENDING RECORD: LOOP CHAMPION
    # Called by base mode at ball ending.
    # If MPF passes no useful value, read the real player var
    # directly from current_player.best_loop_streak_this_game.
    # ------------------------------------------------------------
    def record_candidate_loop_champion(self, **kwargs):

        value = self._get_record_value(kwargs)

        if value <= 0:
            value = self._get_current_player_var_int(
                "best_loop_streak_this_game"
            )

        records = self._load_records()
        current_value = int(records["loop_champion"]["value"])
        pending_value = int(self._pending_records.get("loop_champion", 0))

        if value <= current_value or value <= pending_value:

            self.info_log(
                "Pending Loop Champion skipped -> %s loops not higher than current %s / pending %s",
                value,
                current_value,
                pending_value
            )

            return

        self._pending_records["loop_champion"] = value
        self._mark_machine_record_initials_needed()

        self.info_log(
            "Pending Loop Champion set -> loops: %s",
            value
        )

    # ------------------------------------------------------------
    # PENDING RECORD: MULTIBALL HERO
    # ------------------------------------------------------------
    def record_candidate_multiball_hero(self, **kwargs):

        value = self._get_record_value(kwargs)
        mode_name = self._get_record_mode(kwargs)

        records = self._load_records()
        current_value = int(records["multiball_hero"]["value"])
        pending_value = int(self._pending_records["multiball_hero"]["value"])

        if value <= current_value or value <= pending_value:

            self.info_log(
                "Pending Multiball Hero skipped -> %s not higher than current %s / pending %s",
                value,
                current_value,
                pending_value
            )

            return

        self._pending_records["multiball_hero"] = {
            "value": value,
            "mode": mode_name
        }
        self._mark_machine_record_initials_needed()

        self.info_log(
            "Pending Multiball Hero set -> score: %s mode: %s",
            value,
            mode_name
        )

    # ------------------------------------------------------------
    # PENDING RECORD: VILLAIN MVP
    # ------------------------------------------------------------
    def record_candidate_villain_mvp(self, **kwargs):

        value = self._get_record_value(kwargs)
        mode_name = self._get_record_mode(kwargs)

        records = self._load_records()
        current_value = int(records["villain_mvp"]["value"])
        pending_value = int(self._pending_records["villain_mvp"]["value"])

        if value <= current_value or value <= pending_value:

            self.info_log(
                "Pending Villain MVP skipped -> %s not higher than current %s / pending %s",
                value,
                current_value,
                pending_value
            )

            return

        self._pending_records["villain_mvp"] = {
            "value": value,
            "mode": mode_name
        }
        self._mark_machine_record_initials_needed()

        self.info_log(
            "Pending Villain MVP set -> score: %s mode: %s",
            value,
            mode_name
        )

    # ------------------------------------------------------------
    # APPLY PENDING MACHINE RECORDS
    # Saves pending loop/multiball/villain records with the same
    # player initials used by the high-score entry screen.
    # ------------------------------------------------------------
    def record_apply_pending_records(self, **kwargs):

        name = self._get_record_name(kwargs)

        if name == "---":
            text = kwargs.get("text", None)
            if text is not None:
                name = str(text).strip().upper()[:20]

        if not name or name == "---":
            player = self.machine.game.player if self.machine.game else None
            if player:
                name = self._get_player_name(player).upper()

        if not name:
            name = "---"

        pending = self._pending_records
        any_saved = False

        loop_value = int(pending.get("loop_champion", 0))
        if loop_value > 0:
            self._save_pending_loop_champion(name, loop_value)
            any_saved = True

        multiball = pending.get("multiball_hero", {})
        multiball_value = int(multiball.get("value", 0))
        if multiball_value > 0:
            self._save_pending_multiball_hero(
                name,
                multiball_value,
                multiball.get("mode", "---")
            )
            any_saved = True

        villain = pending.get("villain_mvp", {})
        villain_value = int(villain.get("value", 0))
        if villain_value > 0:
            self._save_pending_villain_mvp(
                name,
                villain_value,
                villain.get("mode", "---")
            )
            any_saved = True

        if any_saved:
            self._pending_records = self._default_pending_records()
            self._set_current_player_var(
                "machine_record_initials_score",
                0
            )
            self.info_log(
                "Pending machine records applied -> player: %s",
                name
            )
        else:
            self.info_log(
                "No pending machine records to apply -> player: %s",
                name
            )

    # ------------------------------------------------------------
    # CLEAR PENDING MACHINE RECORDS
    # ------------------------------------------------------------
    def record_clear_pending_records(self, **kwargs):

        self._pending_records = self._default_pending_records()
        self._set_current_player_var(
            "machine_record_initials_score",
            0
        )
        self.info_log("Pending machine records cleared")

    # ------------------------------------------------------------
    # SAVE PENDING RECORD HELPERS
    # ------------------------------------------------------------
    def _save_pending_loop_champion(self, name, value):

        records = self._load_records()
        current_value = int(records["loop_champion"]["value"])

        if value <= current_value:
            return

        records["loop_champion"] = {
            "name": name,
            "value": value,
            "text": "{} LOOPS".format(value)
        }

        self._save_records(records)
        self._apply_record_machine_vars(records)

        self.info_log(
            "Pending Loop Champion saved -> player: %s loops: %s",
            name,
            value
        )

    def _save_pending_multiball_hero(self, name, value, mode_name):

        records = self._load_records()
        current_value = int(records["multiball_hero"]["value"])

        if value <= current_value:
            return

        records["multiball_hero"] = {
            "name": name,
            "value": value,
            "text": self._format_score(value),
            "mode": mode_name
        }

        self._save_records(records)
        self._apply_record_machine_vars(records)

        self.info_log(
            "Pending Multiball Hero saved -> player: %s score: %s mode: %s",
            name,
            value,
            mode_name
        )

    def _save_pending_villain_mvp(self, name, value, mode_name):

        records = self._load_records()
        current_value = int(records["villain_mvp"]["value"])

        if value <= current_value:
            return

        records["villain_mvp"] = {
            "name": name,
            "value": value,
            "text": self._format_score(value),
            "mode": mode_name
        }

        self._save_records(records)
        self._apply_record_machine_vars(records)

        self.info_log(
            "Pending Villain MVP saved -> player: %s score: %s mode: %s",
            name,
            value,
            mode_name
        )

    # ------------------------------------------------------------
    # MACHINE RECORD INITIALS TRIGGER
    # ------------------------------------------------------------
    # Uses the normal MPF high_score mode safely.
    #
    # high_scores.yaml has an extra hidden/local category:
    #   machine_record_initials_score
    #
    # When any machine record is pending, this player var is set
    # to a fresh timestamp. That makes MPF's normal initials entry
    # appear at game end, even if the normal score top 3 was not beaten.
    # It does not change the normal score category.
    # ------------------------------------------------------------
    def _mark_machine_record_initials_needed(self):

        value = int(time.time())
        self._set_current_player_var(
            "machine_record_initials_score",
            value
        )

        self.info_log(
            "Machine record initials needed -> trigger value: %s",
            value
        )

    # ------------------------------------------------------------
    # SET CURRENT PLAYER VAR HELPER
    # ------------------------------------------------------------
    def _set_current_player_var(self, name, value):

        player = self.machine.game.player if self.machine.game else None

        if not player:
            return

        try:
            player[name] = value
            return
        except Exception:
            pass

        try:
            setattr(player, name, value)
        except Exception:
            self.warning_log(
                "Could not set player var -> %s = %s",
                name,
                value
            )

    # ------------------------------------------------------------
    # CURRENT PLAYER VAR HELPER
    # ------------------------------------------------------------
    def _get_current_player_var_int(self, name):

        player = self.machine.game.player if self.machine.game else None

        if not player:
            return 0

        value = None

        try:
            value = getattr(player, name, None)
        except Exception:
            value = None

        if value is None:
            try:
                value = player[name]
            except Exception:
                value = None

        try:
            return int(value)
        except Exception:
            return 0

    # ------------------------------------------------------------
    # RECORD EVENT: LOOP CHAMPION
    #
    # Manual test event:
    #   record_save_loop_champion{name="ABC", value=123}
    # ------------------------------------------------------------
    def record_save_loop_champion(self, **kwargs):

        name = self._get_record_name(kwargs)
        value = self._get_record_value(kwargs)

        records = self._load_records()
        current_value = int(records["loop_champion"]["value"])

        if value <= current_value:

            self.info_log(
                "Loop Champion skipped -> %s loops not higher than %s",
                value,
                current_value
            )

            return

        records["loop_champion"] = {
            "name": name,
            "value": value,
            "text": "{} LOOPS".format(value)
        }

        self._save_records(records)
        self._apply_record_machine_vars(records)

        self.info_log(
            "Loop Champion saved -> player: %s loops: %s",
            name,
            value
        )

    # ------------------------------------------------------------
    # RECORD EVENT: MULTIBALL HERO
    #
    # Manual test event:
    #   record_save_multiball_hero{name="ABC", value=1000000, mode="NAKATOMI"}
    # ------------------------------------------------------------
    def record_save_multiball_hero(self, **kwargs):

        name = self._get_record_name(kwargs)
        value = self._get_record_value(kwargs)
        mode_name = self._get_record_mode(kwargs)

        records = self._load_records()
        current_value = int(records["multiball_hero"]["value"])

        if value <= current_value:

            self.info_log(
                "Multiball Hero skipped -> %s not higher than %s",
                value,
                current_value
            )

            return

        records["multiball_hero"] = {
            "name": name,
            "value": value,
            "text": self._format_score(value),
            "mode": mode_name
        }

        self._save_records(records)
        self._apply_record_machine_vars(records)

        self.info_log(
            "Multiball Hero saved -> player: %s score: %s mode: %s",
            name,
            value,
            mode_name
        )

    # ------------------------------------------------------------
    # RECORD EVENT: VILLAIN MVP
    #
    # Manual test event:
    #   record_save_villain_mvp{name="ABC", value=1000000, mode="SIMON DIE HARDER"}
    # ------------------------------------------------------------
    def record_save_villain_mvp(self, **kwargs):

        name = self._get_record_name(kwargs)
        value = self._get_record_value(kwargs)
        mode_name = self._get_record_mode(kwargs)

        records = self._load_records()
        current_value = int(records["villain_mvp"]["value"])

        if value <= current_value:

            self.info_log(
                "Villain MVP skipped -> %s not higher than %s",
                value,
                current_value
            )

            return

        records["villain_mvp"] = {
            "name": name,
            "value": value,
            "text": self._format_score(value),
            "mode": mode_name
        }

        self._save_records(records)
        self._apply_record_machine_vars(records)

        self.info_log(
            "Villain MVP saved -> player: %s score: %s mode: %s",
            name,
            value,
            mode_name
        )

    # ------------------------------------------------------------
    # REFRESH MACHINE RECORDS
    # Re-applies saved record machine vars.
    # ------------------------------------------------------------
    def refresh_machine_records(self, **kwargs):

        records = self._load_records()
        self._apply_record_machine_vars(records)

    # ------------------------------------------------------------
    # RECORD HELPERS
    # ------------------------------------------------------------
    def _get_record_name(self, kwargs):

        name = kwargs.get("name", None)

        if name is None:
            name = kwargs.get("initials", None)

        if name is None:
            name = kwargs.get("player_name", None)

        if name is None:
            name = "---"

        name = str(name).strip().upper()

        if not name:
            name = "---"

        return name[:20]

    def _get_record_value(self, kwargs):

        value = kwargs.get("value", None)

        if value is None:
            value = kwargs.get("score", None)

        if value is None:
            value = 0

        try:
            return int(value)
        except Exception:
            return 0

    def _get_record_mode(self, kwargs):

        mode_name = kwargs.get("mode", None)

        if mode_name is None:
            mode_name = kwargs.get("mode_name", None)

        if mode_name is None:
            mode_name = kwargs.get("name_of_mode", None)

        if mode_name is None:
            mode_name = "---"

        mode_name = str(mode_name).strip().upper()

        if not mode_name:
            mode_name = "---"

        return mode_name[:40]

    # ------------------------------------------------------------
    # APPLY RECORD MACHINE VARS
    # These are for your three individual attract record screens.
    # ------------------------------------------------------------
    def _apply_record_machine_vars(self, records):

        records = self._normalise_records(records)

        loop = records["loop_champion"]
        multiball = records["multiball_hero"]
        villain = records["villain_mvp"]

        self._set_machine_var(
            "record_loop_champion_name",
            loop["name"]
        )

        self._set_machine_var(
            "record_loop_champion_value",
            loop["value"]
        )

        self._set_machine_var(
            "record_loop_champion_text",
            loop["text"]
        )

        self._set_machine_var(
            "record_multiball_hero_name",
            multiball["name"]
        )

        self._set_machine_var(
            "record_multiball_hero_value",
            multiball["value"]
        )

        self._set_machine_var(
            "record_multiball_hero_text",
            multiball["text"]
        )

        self._set_machine_var(
            "record_multiball_hero_mode",
            multiball["mode"]
        )

        self._set_machine_var(
            "record_villain_mvp_name",
            villain["name"]
        )

        self._set_machine_var(
            "record_villain_mvp_value",
            villain["value"]
        )

        self._set_machine_var(
            "record_villain_mvp_text",
            villain["text"]
        )

        self._set_machine_var(
            "record_villain_mvp_mode",
            villain["mode"]
        )

        self._set_machine_var(
            "machine_records_last_update",
            int(time.time())
        )

    # ------------------------------------------------------------
    # DEFAULT / NORMALISE RECORDS
    # ------------------------------------------------------------
    def _default_records(self):

        return {
            "loop_champion": {
                "name": "---",
                "value": 0,
                "text": "---"
            },
            "multiball_hero": {
                "name": "---",
                "value": 0,
                "text": "---",
                "mode": "---"
            },
            "villain_mvp": {
                "name": "---",
                "value": 0,
                "text": "---",
                "mode": "---"
            }
        }

    def _normalise_records(self, records):

        defaults = self._default_records()

        if not isinstance(records, dict):
            records = {}

        for key in defaults:

            if key not in records or not isinstance(records[key], dict):
                records[key] = defaults[key]

            for sub_key in defaults[key]:

                if sub_key not in records[key]:
                    records[key][sub_key] = defaults[key][sub_key]

        try:
            records["loop_champion"]["value"] = int(records["loop_champion"]["value"])
        except Exception:
            records["loop_champion"]["value"] = 0

        try:
            records["multiball_hero"]["value"] = int(records["multiball_hero"]["value"])
        except Exception:
            records["multiball_hero"]["value"] = 0

        try:
            records["villain_mvp"]["value"] = int(records["villain_mvp"]["value"])
        except Exception:
            records["villain_mvp"]["value"] = 0

        if records["loop_champion"]["value"] <= 0:
            records["loop_champion"]["name"] = "---"
            records["loop_champion"]["text"] = "---"
        elif not records["loop_champion"].get("text"):
            records["loop_champion"]["text"] = "{} LOOPS".format(
                records["loop_champion"]["value"]
            )

        if records["multiball_hero"]["value"] <= 0:
            records["multiball_hero"]["name"] = "---"
            records["multiball_hero"]["text"] = "---"
            records["multiball_hero"]["mode"] = "---"
        elif not records["multiball_hero"].get("text"):
            records["multiball_hero"]["text"] = self._format_score(
                records["multiball_hero"]["value"]
            )

        if records["villain_mvp"]["value"] <= 0:
            records["villain_mvp"]["name"] = "---"
            records["villain_mvp"]["text"] = "---"
            records["villain_mvp"]["mode"] = "---"
        elif not records["villain_mvp"].get("text"):
            records["villain_mvp"]["text"] = self._format_score(
                records["villain_mvp"]["value"]
            )

        return records

    # ------------------------------------------------------------
    # RUN CALLBACK ON MPF THREAD
    # ------------------------------------------------------------
    def _run_on_mpf_thread(self, callback, *args):

        try:

            loop = self.machine.clock.loop
            loop.call_soon_threadsafe(callback, *args)

        except Exception:

            callback(*args)

    # ------------------------------------------------------------
    # SET MACHINE VAR
    # ------------------------------------------------------------
    def _set_machine_var(self, name, value):

        self.machine.variables.set_machine_var(name, value)

    # ------------------------------------------------------------
    # FORMAT SCORE
    # ------------------------------------------------------------
    def _format_score(self, score):

        try:
            return "{:,}".format(int(score))
        except Exception:
            return str(score)

    # ------------------------------------------------------------
    # POST SCORE TO iSCORED
    # ------------------------------------------------------------
    def _post_to_iscored(self, player_name, score, queue_on_fail):

        params = urllib.parse.urlencode({
            "playerName": player_name,
            "score": score
        })

        url = ISCORED_SUBMIT_URL + "?" + params

        try:

            request = urllib.request.Request(
                url,
                data=b"",
                method="POST",
                headers={
                    "User-Agent": "DieHardMPF/1.0"
                }
            )

            with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
                body = response.read().decode("utf-8", errors="ignore")

            status = "unknown"
            rank = "unknown"

            try:
                result = json.loads(body)
                submitted = result.get("submittedScore", {})
                status = submitted.get("status", "unknown")
                rank = submitted.get("rank", "unknown")
            except Exception:
                result = {}

            if status == "accepted":

                self.info_log(
                    "iScored submit OK -> player: %s score: %s status: %s rank: %s",
                    player_name,
                    score,
                    status,
                    rank
                )

                return True

            preview = body[:300].replace("\n", " ").replace("\r", " ")

            self.warning_log(
                "iScored submit NOT confirmed -> player: %s score: %s status: %s response: %s",
                player_name,
                score,
                status,
                preview
            )

            if queue_on_fail:
                self._queue_score(player_name, score)

            return False

        except Exception as e:

            self.warning_log(
                "iScored submit failed/offline -> player: %s score: %s error: %s",
                player_name,
                score,
                e
            )

            if queue_on_fail:
                self._queue_score(player_name, score)

            return False

    # ------------------------------------------------------------
    # QUEUE SCORE
    # Avoids duplicate same-player/same-score queue entries.
    # ------------------------------------------------------------
    def _queue_score(self, player_name, score):

        queued_score = {
            "playerName": player_name,
            "score": int(score),
            "queuedAt": int(time.time())
        }

        with self._queue_lock:

            queue = self._load_queue()

            for existing in queue:

                try:

                    same_name = existing.get("playerName") == player_name
                    same_score = int(existing.get("score", 0)) == int(score)

                    if same_name and same_score:

                        self.info_log(
                            "iScored score already queued -> player: %s score: %s",
                            player_name,
                            score
                        )

                        return

                except Exception:
                    pass

            queue.append(queued_score)
            self._save_queue(queue)

        self.info_log(
            "iScored score queued -> player: %s score: %s",
            player_name,
            score
        )

    # ------------------------------------------------------------
    # FLUSH QUEUE THREAD
    # Only runs when event iscored_flush_queue is posted.
    # ------------------------------------------------------------
    def _flush_queue_thread(self):

        with self._queue_lock:

            queue = self._load_queue()

            if not queue:
                return

            self.info_log(
                "iScored queue flush started -> %s score(s)",
                len(queue)
            )

            remaining = []

            for queued_score in queue:

                player_name = queued_score.get(
                    "playerName",
                    DEFAULT_PLAYER_NAME
                )

                score = int(queued_score.get("score", 0))

                qualifies = self._score_qualifies_for_top_ten(score)

                if qualifies is True:

                    ok = self._post_to_iscored(
                        player_name=player_name,
                        score=score,
                        queue_on_fail=False
                    )

                    if ok:

                        time.sleep(1.0)

                        if self._submitted_score_is_visible(player_name, score):

                            self.info_log(
                                "iScored queued submit verified -> player: %s score: %s",
                                player_name,
                                score
                            )

                        else:

                            self.warning_log(
                                "iScored queued submit said accepted but score is NOT visible -> player: %s score: %s",
                                player_name,
                                score
                            )

                            remaining.append(queued_score)

                    else:

                        remaining.append(queued_score)

                elif qualifies is False:

                    self.info_log(
                        "iScored queued score discarded, no longer top %s -> player: %s score: %s",
                        TOP_N,
                        player_name,
                        score
                    )

                else:

                    remaining.append(queued_score)

            self._save_queue(remaining)

            if remaining:

                self.warning_log(
                    "iScored queue flush incomplete -> %s score(s) still queued",
                    len(remaining)
                )

            else:

                self.info_log("iScored queue flush complete")

            self._refresh_scores_thread()

    # ------------------------------------------------------------
    # QUEUE FILE PATH
    # ------------------------------------------------------------
    def _queue_path(self):

        return os.path.join(
            self.machine.machine_path,
            QUEUE_FILE_NAME
        )

    # ------------------------------------------------------------
    # CACHE FILE PATH
    # ------------------------------------------------------------
    def _cache_path(self):

        return os.path.join(
            self.machine.machine_path,
            CACHE_FILE_NAME
        )

    # ------------------------------------------------------------
    # RECORDS FILE PATH
    # ------------------------------------------------------------
    def _records_path(self):

        return os.path.join(
            self.machine.machine_path,
            RECORDS_FILE_NAME
        )

    # ------------------------------------------------------------
    # LOAD QUEUE
    # ------------------------------------------------------------
    def _load_queue(self):

        path = self._queue_path()

        if not os.path.exists(path):
            return []

        try:

            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)

        except Exception:
            return []

    # ------------------------------------------------------------
    # SAVE QUEUE
    # ------------------------------------------------------------
    def _save_queue(self, queue):

        path = self._queue_path()

        with open(path, "w", encoding="utf-8") as f:
            json.dump(queue, f, indent=2)

    # ------------------------------------------------------------
    # LOAD CACHE ENTRIES
    # ------------------------------------------------------------
    def _load_cache_entries(self):

        path = self._cache_path()

        if not os.path.exists(path):
            return []

        try:

            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)

            entries = data.get("entries", [])
            return self._normalise_entries(entries)

        except Exception as e:

            self.warning_log(
                "iScored cache load failed: %s",
                e
            )

            return []

    # ------------------------------------------------------------
    # SAVE CACHE ENTRIES
    # ------------------------------------------------------------
    def _save_cache_entries(self, entries):

        entries = self._normalise_entries(entries)

        data = {
            "updatedAt": int(time.time()),
            "entries": entries
        }

        path = self._cache_path()

        with self._cache_lock:

            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)

    # ------------------------------------------------------------
    # LOAD RECORDS
    # ------------------------------------------------------------
    def _load_records(self):

        path = self._records_path()

        if not os.path.exists(path):
            return self._default_records()

        try:

            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)

            return self._normalise_records(data)

        except Exception as e:

            self.warning_log(
                "Machine records load failed: %s",
                e
            )

            return self._default_records()

    # ------------------------------------------------------------
    # SAVE RECORDS
    # ------------------------------------------------------------
    def _save_records(self, records):

        records = self._normalise_records(records)

        path = self._records_path()

        with self._records_lock:

            with open(path, "w", encoding="utf-8") as f:
                json.dump(records, f, indent=2)
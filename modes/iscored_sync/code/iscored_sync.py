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

        self.info_log("iScored integration loaded - multiplayer V6")

        self._queue_lock = threading.Lock()
        self._refresh_lock = threading.Lock()
        self._cache_lock = threading.Lock()
        self._records_lock = threading.Lock()

        self._pending_records = self._default_pending_records()
        self._active_multiball_record = None
        self._active_villain_record = None

        # Multiplayer-safe end-of-game state.
        self._game_player_scores = {}
        self._iscored_players = {}
        self._iscored_submitted_players = set()
        self._active_high_score_player_num = None
        self._game_scores_prepared = False

        # Machine-record ownership. A record made by Player 2 must not be
        # saved using Player 1's initials.
        self._pending_record_player_num = None
        self._pending_record_title = ""
        self._pending_record_value_text = ""

        # Kept for manual/test event compatibility.
        self._pending_iscored_score = None
        self._pending_iscored_player_name = DEFAULT_PLAYER_NAME
        self._iscored_submit_done = False

        self.machine.events.add_handler(
            "game_will_end",
            self.capture_score_and_force_iscored_initials,
            priority=1000
        )

        self.machine.events.add_handler(
            "game_ending",
            self.capture_score_and_force_iscored_initials,
            priority=2000
        )

        self.machine.events.add_handler(
            "game_ended",
            self.capture_score_for_later_iscored_submit
        )

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
            self.refresh_scores,
            priority=0
        )

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
            "record_start_multiball_hero",
            self.record_start_multiball_hero
        )

        self.machine.events.add_handler(
            "record_finish_multiball_hero",
            self.record_finish_multiball_hero
        )

        self.machine.events.add_handler(
            "record_start_villain_mvp",
            self.record_start_villain_mvp
        )

        self.machine.events.add_handler(
            "record_finish_villain_mvp",
            self.record_finish_villain_mvp
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
            "reset_all_scores_and_records",
            self.reset_all_scores_and_records
        )

        # Explicit priorities remove MPF's unordered-handler race warning.
        self.machine.events.add_handler(
            "text_input_high_score_complete",
            self.record_apply_pending_records,
            priority=200
        )

        self.machine.events.add_handler(
            "text_input_high_score_complete",
            self.submit_score,
            priority=100
        )

        # This event tells us exactly which MPF player is entering initials.
        self.machine.events.add_handler(
            "high_score_enter_initials",
            self.prepare_high_score_player,
            priority=10000
        )

        self.machine.events.add_handler(
            "high_score_award_display",
            self.restore_real_score_for_initials_display,
            priority=10000
        )

        self.machine.events.add_handler(
            "text_input_high_score_started",
            self.restore_real_score_for_initials_display,
            priority=10000
        )

        records = self._load_records()
        self._apply_record_machine_vars(records)

        cached_entries = self._load_cache_entries()
        if cached_entries:
            self._apply_leaderboard_machine_vars(cached_entries)

    def capture_score_and_force_iscored_initials(self, **kwargs):

        # game_will_end and game_ending can both fire. Build the player map
        # once so the second event cannot overwrite Player 1 with Player 2.
        if self._game_scores_prepared:
            return

        players = self._get_all_players()

        if not players:
            self.warning_log(
                "iScored multiplayer preparation skipped -> no players"
            )
            return

        self._game_scores_prepared = True
        self._game_player_scores = {}
        self._iscored_players = {}
        self._iscored_submitted_players = set()
        self._active_high_score_player_num = None

        trigger_base = int(time.time() * 1000)

        for index, player in enumerate(players):

            player_num = self._get_player_number(player, index + 1)
            score = self._get_player_score(player)

            self._game_player_scores[player_num] = score

            if score <= 0:
                continue

            qualifies = self._score_qualifies_for_top_ten(score)

            if qualifies is False:
                self.info_log(
                    "iScored Player %s not forced -> score not top %s: %s",
                    player_num,
                    TOP_N,
                    score
                )
                continue

            trigger_value = trigger_base + player_num

            self._iscored_players[player_num] = {
                "score": score,
                "trigger": trigger_value
            }

            self._set_player_var(
                player,
                "machine_record_display_score",
                score
            )

            self._set_player_var(
                player,
                "machine_record_display_score_text",
                self._format_score(score)
            )

            self._set_player_var(
                player,
                "machine_record_initials_score",
                trigger_value
            )

            if qualifies is True:
                self.info_log(
                    "iScored initials forced -> Player %s qualifies for top %s: score %s trigger %s",
                    player_num,
                    TOP_N,
                    score,
                    trigger_value
                )
            else:
                self.warning_log(
                    "iScored initials forced -> Player %s top %s check unavailable: score %s trigger %s",
                    player_num,
                    TOP_N,
                    score,
                    trigger_value
                )

        self.info_log(
            "iScored multiplayer preparation complete -> players: %s qualifying: %s",
            len(self._game_player_scores),
            len(self._iscored_players)
        )

    def capture_score_for_later_iscored_submit(self, **kwargs):

        # The complete multiplayer snapshot is taken at game_will_end.
        # This fallback only runs if an unusual game flow reached game_ended
        # without the normal preparation event.
        if not self._game_scores_prepared:
            self.capture_score_and_force_iscored_initials(**kwargs)

    def submit_fallback_score_if_no_initials(self, **kwargs):

        # Deliberately disabled. Scores are submitted only after the correct
        # player has entered initials. This prevents JohnMcClane fallback posts.
        return

    def submit_score(self, **kwargs):

        player_num = kwargs.get(
            "player_num",
            self._active_high_score_player_num
        )

        try:
            player_num = int(player_num)
        except Exception:
            player_num = None

        if player_num is None:
            self.warning_log(
                "iScored submit skipped -> no active high-score player"
            )
            return

        typed_name = kwargs.get("text", None)

        if typed_name is None:
            typed_name = kwargs.get("initials", None)

        if typed_name is None:
            typed_name = kwargs.get("name", None)

        player = self._get_player_by_number(player_num)

        if typed_name is not None and str(typed_name).strip():
            player_name = str(typed_name).strip().upper()[:20]
        elif player:
            player_name = self._get_player_name(player).upper()
        else:
            player_name = DEFAULT_PLAYER_NAME

        if not player_name:
            player_name = DEFAULT_PLAYER_NAME

        if player:
            self._set_player_var(player, "initials", player_name)
            self._set_player_var(player, "player_initials", player_name)

        # A player can have a normal local high score without qualifying for
        # iScored. Let MPF save those initials, but do not upload the score.
        iscored_entry = self._iscored_players.get(player_num)

        if not iscored_entry:
            self.info_log(
                "iScored submit not required -> Player %s initials: %s",
                player_num,
                player_name
            )
            return

        if player_num in self._iscored_submitted_players:
            self.info_log(
                "iScored submit skipped -> Player %s already submitted",
                player_num
            )
            return

        score = int(iscored_entry.get("score", 0))

        if score <= 0:
            self.warning_log(
                "iScored submit skipped -> Player %s has no valid score",
                player_num
            )
            return

        self._iscored_submitted_players.add(player_num)

        # MPF has already decided the awards for this player, so the hidden
        # trigger can now be cleared safely.
        if player:
            self._set_player_var(
                player,
                "machine_record_initials_score",
                0
            )

        self.info_log(
            "iScored submit requested -> Player %s name: %s score: %s",
            player_num,
            player_name,
            score
        )

        threading.Thread(
            target=self._check_then_submit_or_queue,
            args=(player_name, score),
            daemon=True
        ).start()

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
    def _get_all_players(self):

        game = self.machine.game

        if not game:
            return []

        for attr in ("player_list", "players"):
            try:
                players = getattr(game, attr)
                if players:
                    return list(players)
            except Exception:
                pass

        try:
            if game.player:
                return [game.player]
        except Exception:
            pass

        return []

    def _get_player_number(self, player, fallback=1):

        for attr in ("number", "player_num"):
            try:
                value = getattr(player, attr)
                if value is not None:
                    return int(value)
            except Exception:
                pass

        try:
            return int(player["number"])
        except Exception:
            return int(fallback)

    def _get_player_score(self, player):

        try:
            return int(player.score)
        except Exception:
            pass

        try:
            return int(player["score"])
        except Exception:
            return 0

    def _get_player_by_number(self, player_num):

        try:
            wanted = int(player_num)
        except Exception:
            return None

        for index, player in enumerate(self._get_all_players()):
            if self._get_player_number(player, index + 1) == wanted:
                return player

        return None

    def _set_player_var(self, player, name, value):

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
                "Could not set Player variable -> %s = %s",
                name,
                value
            )

    def prepare_high_score_player(self, **kwargs):

        player_num = kwargs.get("player_num", None)

        try:
            player_num = int(player_num)
        except Exception:
            self.warning_log(
                "High-score display preparation skipped -> missing player_num"
            )
            return

        self._active_high_score_player_num = player_num

        player = self._get_player_by_number(player_num)
        score = int(
            self._game_player_scores.get(
                player_num,
                self._get_player_score(player) if player else 0
            )
        )

        self._set_machine_var(
            "machine_record_pending_score",
            score
        )

        self._set_machine_var(
            "machine_record_pending_score_text",
            self._format_score(score)
        )

        if player:
            self._set_player_var(
                player,
                "machine_record_display_score",
                score
            )
            self._set_player_var(
                player,
                "machine_record_display_score_text",
                self._format_score(score)
            )

        if self._pending_record_player_num == player_num:
            title = self._pending_record_title
            value_text = self._pending_record_value_text
        elif player_num in self._iscored_players:
            title = "NEW iSCORED TOP 10"
            value_text = ""
        else:
            title = ""
            value_text = ""

        self._set_machine_var(
            "machine_record_pending_title",
            title
        )

        self._set_machine_var(
            "machine_record_pending_subtitle",
            "ENTER INITIALS" if title else ""
        )

        self._set_machine_var(
            "machine_record_pending_value_text",
            value_text
        )

        self.info_log(
            "High-score screen prepared -> Player %s score: %s title: %s",
            player_num,
            score,
            title if title else "normal local high score"
        )

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

                    self._remove_pending_score_from_cache_and_apply(
                        player_name,
                        score
                    )

                    self._refresh_scores_thread()

                else:

                    self.warning_log(
                        "iScored submit said accepted but score is not visible yet, NOT queued to avoid duplicate -> player: %s score: %s",
                        player_name,
                        score
                    )

                    # Do not leave a duplicate local pending copy beside the
                    # accepted online score. iScored can be slow to show the
                    # accepted score, but accepted still means do not queue or
                    # duplicate it.
                    self._remove_pending_score_from_cache_and_apply(
                        player_name,
                        score
                    )

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

            # Pending local scores are display placeholders, not confirmed
            # iScored positions. Do not let them raise the online cutoff and
            # prevent another genuinely qualifying score from uploading.
            for entry in entries:
                if entry.get("pending", False):
                    continue
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

            # Keep locally queued scores visible until iScored confirms them.
            # Previously every successful refresh replaced the whole cache,
            # which made an offline/pending machine high score disappear.
            pending_entries = []
            seen_pending = set()

            for entry in self._load_cache_entries():
                if not entry.get("pending", False):
                    continue

                key = (
                    str(entry.get("name", "")).strip().upper(),
                    int(entry.get("score", 0))
                )

                if key in seen_pending:
                    continue

                seen_pending.add(key)
                pending_entries.append(entry)

            for queued_score in self._load_queue():
                try:
                    queued_value = int(queued_score.get("score", 0))
                except Exception:
                    queued_value = 0

                queued_name = str(
                    queued_score.get("playerName", DEFAULT_PLAYER_NAME)
                ).strip()

                key = (queued_name.upper(), queued_value)

                if queued_value <= 0 or key in seen_pending:
                    continue

                seen_pending.add(key)
                pending_entries.append({
                    "rank": "",
                    "name": queued_name or DEFAULT_PLAYER_NAME,
                    "score": queued_value,
                    "score_text": self._format_score(queued_value),
                    "pending": True
                })

            entries = self._normalise_entries(entries + pending_entries)

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
    # REMOVE PENDING SCORE FROM LOCAL CACHE
    # ------------------------------------------------------------
    # When iScored accepts a score, remove the local pending placeholder.
    # Otherwise the screen can show the same name/score twice: one pending
    # local copy plus one confirmed online copy after refresh.
    # ------------------------------------------------------------
    def _remove_pending_score_from_cache_and_apply(self, player_name, score):

        try:
            score_value = int(score)
        except Exception:
            score_value = 0

        target_name = str(player_name).strip().upper()

        entries = []
        removed = False

        for entry in self._load_cache_entries():

            try:
                entry_score = int(entry.get("score", 0))
            except Exception:
                entry_score = 0

            entry_name = str(entry.get("name", "")).strip().upper()
            entry_pending = bool(entry.get("pending", False))

            if entry_pending and entry_name == target_name and entry_score == score_value:
                removed = True
                continue

            entries.append(entry)

        entries = self._normalise_entries(entries)
        self._save_cache_entries(entries)
        self._apply_leaderboard_machine_vars(entries)

        if removed:
            self.info_log(
                "iScored local pending cache removed -> player: %s score: %s",
                player_name,
                score
            )

    # ------------------------------------------------------------
    # NORMALISE ENTRIES
    # Sorts, trims to top 10, fills empty slots.
    # ------------------------------------------------------------
    def _normalise_entries(self, entries):

        clean_entries = []
        seen_entries = {}

        for entry in entries:

            try:
                score_value = int(entry.get("score", 0))
            except Exception:
                score_value = 0

            name = str(entry.get("name", "---")).strip()
            if not name:
                name = "---"

            pending = bool(entry.get("pending", False))

            clean_entry = {
                "rank": "",
                "name": name,
                "score": score_value,
                "score_text": self._format_score(score_value) if score_value > 0 else "---",
                "pending": pending
            }

            # Avoid showing the same player/score twice on the local display.
            # This happens when we insert a local pending score, then iScored
            # refresh returns the accepted online score with the same name/score.
            # Keep the confirmed online entry over the pending placeholder.
            key = (
                name.upper(),
                score_value
            )

            existing_index = seen_entries.get(key, None)

            if existing_index is None:
                seen_entries[key] = len(clean_entries)
                clean_entries.append(clean_entry)
                continue

            existing_entry = clean_entries[existing_index]

            if existing_entry.get("pending", False) and not pending:
                clean_entries[existing_index] = clean_entry

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
        self._set_machine_var(
            "machine_record_pending_value_text",
            "{} LOOPS".format(value)
        )
        self._mark_machine_record_initials_needed("NEW LOOP CHAMPION")

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
        self._set_machine_var(
            "machine_record_pending_value_text",
            self._format_score(value)
        )
        self._mark_machine_record_initials_needed("NEW MULTIBALL HERO")

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
        self._set_machine_var(
            "machine_record_pending_value_text",
            self._format_score(value)
        )
        self._mark_machine_record_initials_needed("NEW VILLAIN MVP")

        self.info_log(
            "Pending Villain MVP set -> score: %s mode: %s",
            value,
            mode_name
        )

    # ------------------------------------------------------------
    # RECORD TRACKER: MULTIBALL HERO START
    # Called by multiball mode start events.
    # Example YAML event arg:
    #   mode: NAKATOMI MULTIBALL
    # ------------------------------------------------------------
    def record_start_multiball_hero(self, **kwargs):

        mode_name = self._get_record_mode(kwargs)
        start_score = self._get_current_player_score()

        self._active_multiball_record = {
            "score": start_score,
            "mode": mode_name
        }

        self.info_log(
            "Multiball Hero tracker started -> mode: %s start_score: %s",
            mode_name,
            start_score
        )

    # ------------------------------------------------------------
    # RECORD TRACKER: MULTIBALL HERO FINISH
    # Called by multiball mode stop/end events.
    # Calculates score earned during that multiball and sends it to
    # the pending-record system.
    # ------------------------------------------------------------
    def record_finish_multiball_hero(self, **kwargs):

        current_score = self._get_current_player_score()
        active = self._active_multiball_record

        if not active:
            self.info_log(
                "Multiball Hero tracker skipped -> no active multiball tracker"
            )
            return

        start_score = int(active.get("score", 0))
        mode_name = active.get("mode", "---")
        value = current_score - start_score

        self._active_multiball_record = None

        if value <= 0:
            self.info_log(
                "Multiball Hero tracker skipped -> mode: %s value: %s",
                mode_name,
                value
            )
            return

        self.info_log(
            "Multiball Hero tracker finished -> mode: %s score: %s",
            mode_name,
            value
        )

        self.record_candidate_multiball_hero(
            value=value,
            mode=mode_name
        )

    # ------------------------------------------------------------
    # RECORD TRACKER: VILLAIN MVP START
    # Called by villain mode start events.
    # Example YAML event arg:
    #   mode: SIMON DIE HARDER
    # ------------------------------------------------------------
    def record_start_villain_mvp(self, **kwargs):

        mode_name = self._get_record_mode(kwargs)
        start_score = self._get_current_player_score()

        self._active_villain_record = {
            "score": start_score,
            "mode": mode_name
        }

        self.info_log(
            "Villain MVP tracker started -> mode: %s start_score: %s",
            mode_name,
            start_score
        )

    # ------------------------------------------------------------
    # RECORD TRACKER: VILLAIN MVP FINISH
    # Called by villain mode stop/end events.
    # Calculates score earned during that villain mode and sends it
    # to the pending-record system.
    # ------------------------------------------------------------
    def record_finish_villain_mvp(self, **kwargs):

        current_score = self._get_current_player_score()
        active = self._active_villain_record

        if not active:
            self.info_log(
                "Villain MVP tracker skipped -> no active villain tracker"
            )
            return

        start_score = int(active.get("score", 0))
        mode_name = active.get("mode", "---")
        value = current_score - start_score

        self._active_villain_record = None

        if value <= 0:
            self.info_log(
                "Villain MVP tracker skipped -> mode: %s value: %s",
                mode_name,
                value
            )
            return

        self.info_log(
            "Villain MVP tracker finished -> mode: %s score: %s",
            mode_name,
            value
        )

        self.record_candidate_villain_mvp(
            value=value,
            mode=mode_name
        )

    # ------------------------------------------------------------
    # APPLY PENDING MACHINE RECORDS
    # Saves pending loop/multiball/villain records with the same
    # player initials used by the high-score entry screen.
    # ------------------------------------------------------------
    def record_apply_pending_records(self, **kwargs):

        player_num = kwargs.get(
            "player_num",
            self._active_high_score_player_num
        )

        try:
            player_num = int(player_num)
        except Exception:
            player_num = None

        pending = self._pending_records

        has_pending = (
            int(pending.get("loop_champion", 0)) > 0
            or int(pending.get("multiball_hero", {}).get("value", 0)) > 0
            or int(pending.get("villain_mvp", {}).get("value", 0)) > 0
        )

        if not has_pending:
            return

        # Do not give Player 2's machine record to Player 1 merely because
        # Player 1 was the first person MPF asked for initials.
        if (
            self._pending_record_player_num is not None
            and player_num != self._pending_record_player_num
        ):
            self.info_log(
                "Pending machine records held -> belong to Player %s, current initials are Player %s",
                self._pending_record_player_num,
                player_num
            )
            return

        name = self._get_record_name(kwargs)

        if name == "---":
            text_value = kwargs.get("text", None)
            if text_value is not None:
                name = str(text_value).strip().upper()[:20]

        player = self._get_player_by_number(player_num)

        if (not name or name == "---") and player:
            name = self._get_player_name(player).upper()

        if not name:
            name = "---"

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

        if player:
            self._set_player_var(
                player,
                "machine_record_initials_score",
                0
            )

        self._pending_records = self._default_pending_records()
        self._pending_record_player_num = None
        self._pending_record_title = ""
        self._pending_record_value_text = ""

        self._set_machine_var(
            "machine_record_pending_title",
            ""
        )
        self._set_machine_var(
            "machine_record_pending_subtitle",
            ""
        )
        self._set_machine_var(
            "machine_record_pending_value_text",
            ""
        )

        if any_saved:
            self.info_log(
                "Pending machine records applied -> Player %s name: %s",
                player_num,
                name
            )

    def record_clear_pending_records(self, **kwargs):

        self._pending_records = self._default_pending_records()
        self._pending_record_player_num = None
        self._pending_record_title = ""
        self._pending_record_value_text = ""

        for player in self._get_all_players():
            self._set_player_var(
                player,
                "machine_record_initials_score",
                0
            )

        self._set_machine_var(
            "machine_record_pending_title",
            ""
        )
        self._set_machine_var(
            "machine_record_pending_subtitle",
            ""
        )
        self._set_machine_var(
            "machine_record_pending_value_text",
            ""
        )

        self.info_log("Pending machine records cleared")

    def reset_all_scores_and_records(self, **kwargs):

        files_to_delete = [
            self._records_path(),
            self._cache_path(),
            self._queue_path(),
            os.path.join(self.machine.machine_path, "data", "high_scores.yaml")
        ]

        for path in files_to_delete:

            try:

                if os.path.exists(path):
                    os.remove(path)

                    self.info_log(
                        "Deleted score/reset file -> %s",
                        path
                    )

            except Exception as e:

                self.warning_log(
                    "Could not delete score/reset file -> %s error: %s",
                    path,
                    e
                )

        self._pending_records = self._default_pending_records()
        self._active_multiball_record = None
        self._active_villain_record = None

        records = self._default_records()
        self._apply_record_machine_vars(records)

        self._set_current_player_var(
            "machine_record_initials_score",
            0
        )

        self._set_machine_var(
            "machine_record_pending_title",
            ""
        )

        self._set_machine_var(
            "machine_record_pending_subtitle",
            ""
        )
        self._set_machine_var(
            "machine_record_pending_value_text",
            ""
        )

        self.machine.events.post("reset_local_high_scores")
        self.machine.events.post("record_refresh_machine_records")

        self.info_log(
            "ALL LOCAL SCORES AND MACHINE RECORDS RESET"
        )

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
    # FORCE iSCORED INITIALS TRIGGER
    # ------------------------------------------------------------
    # Uses the same hidden high-score trigger as machine records,
    # but does not overwrite an existing machine-record title.
    # ------------------------------------------------------------
    def _force_iscored_initials_needed(self):

        try:
            display_value = int(self._pending_iscored_score)
        except Exception:
            display_value = self._get_current_player_score()

        if display_value <= 0:
            display_value = self._get_current_player_score()

        if display_value <= 0:
            display_value = 0

        # IMPORTANT:
        # machine_record_initials_score is the hidden MPF high-score trigger.
        # It must be a huge always-new value or MPF will skip initials if an
        # older hidden MACHINE RECORD value is higher.
        #
        # The real player score is kept separately for display and for the
        # actual iScored submit.
        trigger_value = int(time.time() * 1000)

        if trigger_value <= display_value:
            trigger_value = display_value + 1000000000000

        existing_title = ""

        try:
            existing_title = self.machine.variables.get_machine_var(
                "machine_record_pending_title"
            )
        except Exception:
            existing_title = ""

        if not existing_title:
            self._set_machine_var(
                "machine_record_pending_title",
                "NEW iSCORED TOP 10"
            )

            self._set_machine_var(
                "machine_record_pending_subtitle",
                "ENTER INITIALS"
            )

            self._set_machine_var(
                "machine_record_pending_value_text",
                ""
            )

        self._set_machine_var(
            "machine_record_pending_score",
            display_value
        )

        self._set_machine_var(
            "machine_record_pending_score_text",
            self._format_score(display_value)
        )

        self._set_current_player_var(
            "machine_record_display_score",
            display_value
        )

        self._set_current_player_var(
            "machine_record_display_score_text",
            self._format_score(display_value)
        )

        self._set_current_player_var(
            "machine_record_initials_score",
            trigger_value
        )

        self.info_log(
            "iScored initials trigger set -> display score: %s trigger: %s",
            display_value,
            trigger_value
        )

    # ------------------------------------------------------------
    # RESTORE REAL SCORE FOR INITIALS DISPLAY
    # ------------------------------------------------------------
    # MPF must keep the fake hidden trigger until initials entry has
    # completed. This method restores only the separate real-score display
    # variables and deliberately leaves machine_record_initials_score alone.
    # ------------------------------------------------------------
    def restore_real_score_for_initials_display(self, **kwargs):

        player_num = kwargs.get(
            "player_num",
            self._active_high_score_player_num
        )

        try:
            player_num = int(player_num)
        except Exception:
            return

        # Reapply the correct player's display fields without touching the
        # huge hidden trigger that MPF is using internally.
        self.prepare_high_score_player(
            player_num=player_num
        )

    def _reset_hidden_initials_high_score_data(self):

        path = os.path.join(
            self.machine.machine_path,
            "data",
            "high_scores.yaml"
        )

        try:
            import yaml
        except Exception as e:
            self.warning_log(
                "Could not import yaml to reset hidden high-score trigger: %s",
                e
            )
            return

        try:
            data = {}

            if os.path.exists(path):
                with open(path, "r", encoding="utf-8") as f:
                    loaded = yaml.safe_load(f)

                if isinstance(loaded, dict):
                    data = loaded

            data["machine_record_initials_score"] = [
                {"VPX": 0}
            ]

            os.makedirs(
                os.path.dirname(path),
                exist_ok=True
            )

            with open(path, "w", encoding="utf-8") as f:
                yaml.safe_dump(
                    data,
                    f,
                    default_flow_style=False,
                    sort_keys=False
                )

            self.info_log(
                "Hidden high-score initials trigger reset -> %s",
                path
            )

        except Exception as e:
            self.warning_log(
                "Could not reset hidden high-score initials trigger: %s",
                e
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
    #
    # Also sets machine vars for the Godot high-score initials screen
    # so it can show the correct record title.
    # ------------------------------------------------------------
    def _mark_machine_record_initials_needed(self, title="NEW MACHINE RECORD"):

        player = self.machine.game.player if self.machine.game else None

        if not player:
            return

        player_num = self._get_player_number(player, 1)
        score = self._get_player_score(player)
        trigger_value = int(time.time() * 1000) + player_num

        self._pending_record_player_num = player_num
        self._pending_record_title = str(title)

        try:
            loop_value = int(self._pending_records.get("loop_champion", 0))
        except Exception:
            loop_value = 0

        if loop_value > 0 and "LOOP" in str(title).upper():
            value_text = "{} LOOPS".format(loop_value)
        else:
            multiball_value = int(
                self._pending_records.get(
                    "multiball_hero",
                    {}
                ).get("value", 0)
            )
            villain_value = int(
                self._pending_records.get(
                    "villain_mvp",
                    {}
                ).get("value", 0)
            )

            if multiball_value > 0 and "MULTIBALL" in str(title).upper():
                value_text = self._format_score(multiball_value)
            elif villain_value > 0 and "VILLAIN" in str(title).upper():
                value_text = self._format_score(villain_value)
            else:
                value_text = ""

        self._pending_record_value_text = value_text

        self._set_machine_var(
            "machine_record_pending_title",
            str(title)
        )

        self._set_machine_var(
            "machine_record_pending_subtitle",
            "ENTER INITIALS"
        )

        self._set_machine_var(
            "machine_record_pending_score",
            score
        )

        self._set_machine_var(
            "machine_record_pending_score_text",
            self._format_score(score)
        )

        self._set_machine_var(
            "machine_record_pending_value_text",
            value_text
        )

        self._set_player_var(
            player,
            "machine_record_display_score",
            score
        )

        self._set_player_var(
            player,
            "machine_record_display_score_text",
            self._format_score(score)
        )

        self._set_player_var(
            player,
            "machine_record_initials_score",
            trigger_value
        )

        self.info_log(
            "Machine record initials needed -> Player %s title: %s value: %s trigger: %s",
            player_num,
            title,
            value_text,
            trigger_value
        )

    def _get_current_player_score(self):

        player = self.machine.game.player if self.machine.game else None

        if not player:
            return 0

        try:
            return int(player.score)
        except Exception:
            pass

        try:
            return int(player["score"])
        except Exception:
            return 0

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

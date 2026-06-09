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
TOP_N = 10
HTTP_TIMEOUT = 2


class IscoredSync(Mode):

    # ------------------------------------------------------------
    # MODE START
    # Registers events only.
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

        # Apply any saved local cache straight away.
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
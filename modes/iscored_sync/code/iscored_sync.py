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
    # Checks top 10 before posting.
    #
    # Important:
    # iScored may return accepted but not actually show the score
    # in the following leaderboard GET, so we verify it.
    # ------------------------------------------------------------
    def _check_then_submit_or_queue(self, player_name, score):

        qualifies = self._score_qualifies_for_top_ten(score)

        if qualifies is True:

            self.info_log(
                "iScored score qualifies for top %s -> player: %s score: %s",
                TOP_N,
                player_name,
                score
            )

            ok = self._post_to_iscored(
                player_name=player_name,
                score=score,
                queue_on_fail=True
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

            return

        if qualifies is False:

            self.info_log(
                "iScored skipped -> score not top %s: player: %s score: %s",
                TOP_N,
                player_name,
                score
            )

            return

        self.warning_log(
            "iScored could not check leaderboard, queued for later -> player: %s score: %s",
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
    # ------------------------------------------------------------
    def _score_qualifies_for_top_ten(self, score):

        try:
            scores = self._get_top_scores()

            if len(scores) < TOP_N:

                self.info_log(
                    "iScored leaderboard has fewer than %s scores, score qualifies",
                    TOP_N
                )

                return True

            tenth_score = scores[TOP_N - 1]

            self.info_log(
                "iScored top %s cutoff is %s, player score is %s",
                TOP_N,
                tenth_score,
                score
            )

            return int(score) > int(tenth_score)

        except Exception as e:

            self.warning_log("iScored leaderboard check failed: %s", e)
            return None

    # ------------------------------------------------------------
    # GET TOP SCORES
    # ------------------------------------------------------------
    def _get_top_scores(self):

        entries = self._get_leaderboard_entries(TOP_N)

        scores = []

        for entry in entries:
            try:
                scores.append(int(entry.get("score", 0)))
            except Exception:
                pass

        scores.sort(reverse=True)

        return scores

    # ------------------------------------------------------------
    # GET LEADERBOARD ENTRIES
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
                "score_text": self._format_score(score_value)
            })

        return entries

    # ------------------------------------------------------------
    # REFRESH SCORES THREAD
    # Prevents overlapping leaderboard refreshes.
    # ------------------------------------------------------------
    def _refresh_scores_thread(self):

        if not self._refresh_lock.acquire(blocking=False):

            self.info_log("iScored leaderboard refresh already running, skipped")
            return

        try:

            entries = self._get_leaderboard_entries(TOP_N)

            self._run_on_mpf_thread(
                self._apply_leaderboard_machine_vars,
                entries
            )

        except Exception as e:

            self.warning_log(
                "iScored leaderboard refresh failed: %s",
                e
            )

        finally:

            self._refresh_lock.release()

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

        # Apply real values.
        for index in range(TOP_N):

            slot = index + 1

            if index < len(entries):

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

            else:

                self._set_machine_var(
                    "iscored_{}_rank".format(slot),
                    str(slot)
                )

                self._set_machine_var(
                    "iscored_{}_name".format(slot),
                    "---"
                )

                self._set_machine_var(
                    "iscored_{}_score".format(slot),
                    0
                )

                self._set_machine_var(
                    "iscored_{}_score_text".format(slot),
                    "---"
                )

        self._set_machine_var(
            "iscored_last_update",
            int(time.time())
        )

        self.info_log(
            "iScored leaderboard updated -> %s score(s)",
            len(entries)
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
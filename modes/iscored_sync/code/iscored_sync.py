import importlib.machinery
import importlib.util
import os


_COMPILED_PATH = os.path.join(os.path.dirname(__file__), "iscored_sync.pyc")
_LOADER = importlib.machinery.SourcelessFileLoader(
    "_iscored_sync_compiled",
    _COMPILED_PATH
)
_SPEC = importlib.util.spec_from_loader("_iscored_sync_compiled", _LOADER)
_COMPILED = importlib.util.module_from_spec(_SPEC)
_LOADER.exec_module(_COMPILED)

_ORIGINAL_MODE_START = _COMPILED.IscoredSync.mode_start
_ORIGINAL_SUBMIT_SCORE = _COMPILED.IscoredSync.submit_score
_ORIGINAL_CAPTURE_AND_FORCE = (
    _COMPILED.IscoredSync.capture_score_and_force_iscored_initials
)


def _score_qualifies_for_top_ten_with_full_refresh(self, score):
    try:
        top_n = int(getattr(_COMPILED, "TOP_N", 10))
        entries = self._load_cache_entries()

        if not entries:
            self.info_log(
                "iScored no local cache yet, checking online leaderboard"
            )
            entries = self._get_leaderboard_entries(top_n)
            entries = self._normalise_entries(entries)
            self._save_cache_entries(entries)

        scores = []

        for entry in entries:
            if entry.get("pending", False):
                continue
            try:
                scores.append(int(entry.get("score", 0)))
            except Exception:
                scores.append(0)

        if len(scores) < top_n:
            self.info_log(
                "iScored local cache has only %s confirmed score(s), refreshing online before cutoff check",
                len(scores)
            )
            entries = self._get_leaderboard_entries(top_n)
            entries = self._normalise_entries(entries)
            self._save_cache_entries(entries)

            scores = []
            for entry in entries:
                if entry.get("pending", False):
                    continue
                try:
                    scores.append(int(entry.get("score", 0)))
                except Exception:
                    scores.append(0)

        while len(scores) < top_n:
            scores.append(0)

        scores.sort(reverse=True)
        tenth_score = scores[top_n - 1]

        self.info_log(
            "iScored cached top %s cutoff is %s, player score is %s",
            top_n,
            tenth_score,
            score
        )

        return int(score) > int(tenth_score)

    except Exception as e:
        self.warning_log("iScored cached leaderboard check failed: %s", e)
        return None


_COMPILED.IscoredSync._score_qualifies_for_top_ten = (
    _score_qualifies_for_top_ten_with_full_refresh
)


def _mode_start_with_submitted_score_tracking(self, **kwargs):
    self._iscored_submitted_player_scores = set()
    return _ORIGINAL_MODE_START(self, **kwargs)


def _submit_score_with_submitted_score_tracking(self, **kwargs):
    player_num = kwargs.get(
        "player_num",
        getattr(self, "_active_high_score_player_num", None)
    )

    try:
        player_num = int(player_num)
    except Exception:
        player_num = None

    score = 0

    if player_num is not None:
        try:
            iscored_entry = getattr(self, "_iscored_players", {}).get(
                player_num
            )
            if iscored_entry:
                score = int(iscored_entry.get("score", 0))
        except Exception:
            score = 0

    result = _ORIGINAL_SUBMIT_SCORE(self, **kwargs)

    if player_num is not None and score > 0:
        try:
            self._iscored_submitted_player_scores.add((player_num, score))
            self.info_log(
                "iScored submitted score remembered -> Player %s score %s",
                player_num,
                score
            )
        except Exception:
            pass

    return result


def _capture_score_and_force_skip_submitted(self, **kwargs):
    if not hasattr(self, "_iscored_submitted_player_scores"):
        self._iscored_submitted_player_scores = set()

    players = self._get_all_players()
    hidden_saved = []

    for index, player in enumerate(players):
        try:
            player_num = self._get_player_number(player, index + 1)
            score = self._get_player_score(player)
        except Exception:
            continue

        if (player_num, score) not in self._iscored_submitted_player_scores:
            continue

        try:
            current_trigger = player["machine_record_initials_score"]
        except Exception:
            try:
                current_trigger = getattr(
                    player,
                    "machine_record_initials_score",
                    0
                )
            except Exception:
                current_trigger = 0

        hidden_saved.append((player, current_trigger, player_num, score))

        try:
            player["machine_record_initials_score"] = 0
        except Exception:
            try:
                setattr(player, "machine_record_initials_score", 0)
            except Exception:
                pass

        self.info_log(
            "iScored initials force skipped -> Player %s score %s already submitted",
            player_num,
            score
        )

    try:
        return _ORIGINAL_CAPTURE_AND_FORCE(self, **kwargs)
    finally:
        for player, current_trigger, player_num, score in hidden_saved:
            try:
                player["machine_record_initials_score"] = current_trigger
            except Exception:
                try:
                    setattr(
                        player,
                        "machine_record_initials_score",
                        current_trigger
                    )
                except Exception:
                    pass


_COMPILED.IscoredSync.mode_start = _mode_start_with_submitted_score_tracking
_COMPILED.IscoredSync.submit_score = _submit_score_with_submitted_score_tracking
_COMPILED.IscoredSync.capture_score_and_force_iscored_initials = (
    _capture_score_and_force_skip_submitted
)

globals().update(
    {
        name: value
        for name, value in _COMPILED.__dict__.items()
        if not name.startswith("__")
    }
)

IscoredSync = _COMPILED.IscoredSync

from mpf.modes.high_score.code.high_score import HighScore


PER_PLAYER_DONE_VAR = "final_ball_high_score_done"


class PerPlayerHighScore(HighScore):

    """Run high-score entry when a player's final turn ends."""

    def __init__(self, *args, **kwargs):

        self._started_from_player_turn = False
        self._turn_ending_player = None
        super().__init__(*args, **kwargs)

    def mode_will_start(self, **kwargs):

        self._started_from_player_turn = False
        self._turn_ending_player = None

        player = kwargs.get("player", None)

        if player:
            self._started_from_player_turn = True

        if player and self._is_players_final_turn(player):
            self._turn_ending_player = player

    def _get_players(self):

        players = list(super()._get_players())

        if not players:
            return players

        if self._turn_ending_player:
            player = self._turn_ending_player

            if self._player_done(player):
                return []

            self._prepare_iscored_for_player(player)
            return [player]

        if self._started_from_player_turn:
            return []

        return [
            player for player in players
            if not self._player_done(player)
        ]

    async def _ask_player_for_initials(
            self, player_number, award_label, value, category_name):

        initials = await super()._ask_player_for_initials(
            player_number,
            award_label,
            value,
            category_name
        )

        player = self._player_by_number(player_number)

        if player:
            self._set_player_var(player, PER_PLAYER_DONE_VAR, True)

        return initials

    def _is_players_final_turn(self, player):

        balls_per_game = self._balls_per_game()

        if balls_per_game <= 0:
            return False

        try:
            return int(player.ball) >= balls_per_game
        except Exception:
            pass

        try:
            return int(player["ball"]) >= balls_per_game
        except Exception:
            return False

    def _balls_per_game(self):

        try:
            return int(self.machine.game.balls_per_game)
        except Exception:
            pass

        try:
            return int(self.machine.config["game"]["balls_per_game"])
        except Exception:
            return 0

    def _prepare_iscored_for_player(self, player):

        iscored = self._iscored_mode()

        if not iscored:
            return

        player_num = self._player_number(player)
        score = self._player_score(player)

        try:
            iscored._game_player_scores[player_num] = score
        except Exception:
            pass

        if score <= 0:
            return

        try:
            qualifies = iscored._score_qualifies_for_top_ten(score)
        except Exception:
            qualifies = False

        if qualifies is False:
            return

        try:
            import time
            trigger_value = int(time.time() * 1000) + player_num

            iscored._iscored_players[player_num] = {
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
                iscored._format_score(score)
            )
            self._set_player_var(
                player,
                "machine_record_initials_score",
                trigger_value
            )
        except Exception:
            return

    def _iscored_mode(self):

        try:
            return self.machine.modes["iscored_sync"]
        except Exception:
            pass

        try:
            return self.machine.modes.get("iscored_sync")
        except Exception:
            return None

    def _player_done(self, player):

        try:
            return bool(player[PER_PLAYER_DONE_VAR])
        except Exception:
            return False

    def _player_by_number(self, player_number):

        try:
            wanted = int(player_number)
        except Exception:
            return None

        try:
            players = self.machine.game.player_list
        except Exception:
            return None

        for player in players:
            if self._player_number(player) == wanted:
                return player

        return None

    def _player_number(self, player):

        try:
            return int(player.number)
        except Exception:
            pass

        try:
            return int(player["number"])
        except Exception:
            return 1

    def _player_score(self, player):

        try:
            return int(player.score)
        except Exception:
            pass

        try:
            return int(player["score"])
        except Exception:
            return 0

    def _set_player_var(self, player, name, value):

        try:
            player[name] = value
            return
        except Exception:
            pass

        try:
            setattr(player, name, value)
        except Exception:
            return

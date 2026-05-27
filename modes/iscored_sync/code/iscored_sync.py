from mpf.core.mode import Mode


class IscoredSync(Mode):

    def mode_start(self, **kwargs):

        self.info_log("iScored integration loaded")

        self.machine.events.add_handler(
            "iscored_submit_score",
            self.test_submit
        )

    def test_submit(self, **kwargs):

        player = self.machine.game.player if self.machine.game else None

        if not player:
            self.warning_log("No player found")
            return

        self.info_log(
            "TEST iScored submit -> score: %s",
            player.score
        )
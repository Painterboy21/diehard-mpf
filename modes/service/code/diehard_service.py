from mpf.core.mode import Mode


class DieHardService(Mode):
    """Custom Die Hard service overlay without MPF's reset-on-exit behavior."""

    __slots__ = [
        "_service_locked",
        "_enabled_autofires",
        "_enabled_ball_saves",
        "_enabled_flippers",
        "_enabled_magnets",
        "_enabled_shots",
        "_running_timers",
        "_rotating_shot_groups",
        "_service_started_during_game",
    ]

    def mode_start(self, **kwargs):
        del kwargs
        self._clear_restore_state()
        self.add_mode_event_handler("service_mode_entered", self._service_entered)
        self.add_mode_event_handler("service_mode_exited", self._service_exited)
        self.add_mode_event_handler("service_reset_game_requested", self._reset_game_requested)

    def _service_entered(self, **kwargs):
        del kwargs
        if self._service_locked:
            return

        self._clear_restore_state()
        self._service_locked = True
        self._service_started_during_game = bool(self.machine.game)
        self.machine.variables.set_machine_var("service_mode_active", 1)

        if not self._service_started_during_game:
            return

        self._disable_magnets()
        self._disable_autofires()
        self._disable_flippers()

        for playfield in self.machine.playfields.values():
            playfield.ball_search.block()

        self._pause_timers()
        self._disable_ball_saves()
        self._disable_shot_logic()
        self._disable_shot_group_rotation()

    def _service_exited(self, restore_game=True, **kwargs):
        del kwargs
        if not restore_game:
            if self._service_started_during_game:
                self._unblock_ball_search()
            self._service_locked = False
            self.machine.variables.set_machine_var("service_mode_active", 0)
            self._clear_restore_state()
            return

        if not self._service_locked:
            self.machine.variables.set_machine_var("service_mode_active", 0)
            return

        self._service_locked = False
        self.machine.variables.set_machine_var("service_mode_active", 0)

        self._restore_flippers()
        self._restore_autofires()
        self._restore_magnets()

        if not self._service_started_during_game:
            self._clear_restore_state()
            return

        self._unblock_ball_search()
        self._restore_shot_group_rotation()
        self._restore_shot_logic()
        self._restore_ball_saves()
        self._resume_timers()
        self._clear_restore_state()

    def _reset_game_requested(self, **kwargs):
        del kwargs

        self.machine.events.post("service_mode_exited", restore_game=False)

        for mode in self.machine.modes.values():
            if not mode.active or mode.name in ("game", "service"):
                continue
            mode.stop()

        if self.machine.modes["game"].active:
            self.machine.modes["game"].stop()

        self.machine.clock.loop.create_task(self.machine.reset())

    def _clear_restore_state(self):
        self._service_locked = False
        self._enabled_autofires = set()
        self._enabled_ball_saves = set()
        self._enabled_flippers = set()
        self._enabled_magnets = set()
        self._enabled_shots = set()
        self._running_timers = set()
        self._rotating_shot_groups = set()
        self._service_started_during_game = False

    def _safe_call(self, device, method_name):
        method = getattr(device, method_name, None)
        if not method:
            return

        try:
            method()
        except Exception as exc:  # pragma: no cover - service mode should keep running.
            self.warning_log("Service mode could not %s %s: %s", method_name, device.name, exc)

    def _is_enabled(self, device):
        return bool(getattr(device, "enabled", getattr(device, "_enabled", False)))

    def _unblock_ball_search(self):
        for playfield in self.machine.playfields.values():
            playfield.ball_search.unblock()

    def _disable_autofires(self):
        for name, autofire in self.machine.autofire_coils.items():
            if self._is_enabled(autofire):
                self._enabled_autofires.add(name)
            self._safe_call(autofire, "disable")

    def _restore_autofires(self):
        for name in self._enabled_autofires:
            autofire = self.machine.autofire_coils.get(name)
            if autofire:
                self._safe_call(autofire, "enable")

    def _disable_flippers(self):
        for name, flipper in self.machine.flippers.items():
            if self._is_enabled(flipper):
                self._enabled_flippers.add(name)
            self._safe_call(flipper, "disable")

    def _restore_flippers(self):
        for name in self._enabled_flippers:
            flipper = self.machine.flippers.get(name)
            if flipper:
                self._safe_call(flipper, "enable")

    def _disable_magnets(self):
        for name, magnet in getattr(self.machine, "magnets", {}).items():
            if self._is_enabled(magnet):
                self._enabled_magnets.add(name)
            self._safe_call(magnet, "disable")

    def _restore_magnets(self):
        for name in self._enabled_magnets:
            magnet = getattr(self.machine, "magnets", {}).get(name)
            if magnet:
                self._safe_call(magnet, "enable")

    def _disable_shot_logic(self):
        for name, shot in getattr(self.machine, "shots", {}).items():
            if self._is_enabled(shot):
                self._enabled_shots.add(name)
            self._safe_call(shot, "disable")

    def _restore_shot_logic(self):
        for name in self._enabled_shots:
            shot = getattr(self.machine, "shots", {}).get(name)
            if shot:
                self._safe_call(shot, "enable")

    def _disable_shot_group_rotation(self):
        for name, shot_group in getattr(self.machine, "shot_groups", {}).items():
            if getattr(shot_group, "rotation_enabled", False):
                self._rotating_shot_groups.add(name)
            self._safe_call(shot_group, "disable_rotation")

    def _restore_shot_group_rotation(self):
        for name in self._rotating_shot_groups:
            shot_group = getattr(self.machine, "shot_groups", {}).get(name)
            if shot_group:
                self._safe_call(shot_group, "enable_rotation")

    def _disable_ball_saves(self):
        for name, ball_save in getattr(self.machine, "ball_saves", {}).items():
            if self._is_enabled(ball_save):
                self._enabled_ball_saves.add(name)
            self._safe_call(ball_save, "disable")

    def _restore_ball_saves(self):
        for name in self._enabled_ball_saves:
            ball_save = getattr(self.machine, "ball_saves", {}).get(name)
            if ball_save:
                self._safe_call(ball_save, "enable")

    def _pause_timers(self):
        for name, timer in getattr(self.machine, "timers", {}).items():
            if getattr(timer, "running", False):
                self._running_timers.add(name)
                self._safe_call(timer, "pause")

    def _resume_timers(self):
        for name in self._running_timers:
            timer = getattr(self.machine, "timers", {}).get(name)
            if timer:
                self._safe_call(timer, "start")

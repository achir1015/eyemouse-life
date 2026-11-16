extends Node
## 作業系統功能：系統音量、電源（市電）監測、縮小到桌面、關機重開。
## 目前實作 Windows；macOS 版之後補上（osascript / pmset）。

signal power_changed(on_ac: bool)

var has_battery := false
var on_ac := true
var _thread: Thread
var _stop := false
var _mutex := Mutex.new()
var _result := -1               # 背景執行緒查到的 BatteryStatus
var fake_power := -1            # 測試用：--fake-power-loss


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--fake-power-loss"):
		fake_power = 1
	if is_windows() or is_mac():
		_thread = Thread.new()
		_thread.start(_poll_power)


func is_windows() -> bool:
	return OS.get_name() == "Windows"


func is_mac() -> bool:
	return OS.get_name() == "macOS"


func _exit_tree() -> void:
	_stop = true
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


# ---------------------------------------------------------------- 電源
func _poll_power() -> void:
	var wait := 0.0
	while not _stop:
		if wait <= 0.0:
			var st := _query_power()
			_mutex.lock()
			_result = st
			_mutex.unlock()
			wait = 12.0
		OS.delay_msec(250)
		wait -= 0.25


## 回傳：-1 無電池／查不到；1 用電池；2 接市電
func _query_power() -> int:
	var out := []
	if is_windows():
		var code := OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command",
			"$b=Get-CimInstance Win32_Battery; if($b){[int]($b|Select-Object -First 1).BatteryStatus}else{-1}"], out, false, false)
		if code != 0 or out.is_empty():
			return -1
		var s := str(out[0]).strip_edges()
		if not s.is_valid_int():
			return -1
		var n := int(s)
		if n < 0:
			return -1
		return 1 if n == 1 or (n >= 4 and n <= 5) else 2   # 1 放電中、4/5 電量低而放電
	elif is_mac():
		OS.execute("pmset", ["-g", "batt"], out)
		if out.is_empty():
			return -1
		var t := str(out[0])
		if not t.contains("InternalBattery"):
			return -1
		return 2 if t.contains("AC Power") else 1
	return -1


func _process(_dt: float) -> void:
	_mutex.lock()
	var r := _result
	_result = -999
	_mutex.unlock()
	if fake_power >= 0:
		r = fake_power
	if r == -999:
		return
	if r == -1:
		has_battery = false
		return
	has_battery = true
	var ac := r == 2
	if ac != on_ac:
		on_ac = ac
		power_changed.emit(ac)


# ---------------------------------------------------------------- 音量
func _sendkey(code: int, times := 1) -> void:
	if is_windows():
		var cmd := "$w=New-Object -ComObject WScript.Shell; 1..%d | %% { $w.SendKeys([char]%d) }" % [times, code]
		OS.create_process("powershell.exe", ["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", cmd])


func volume_up(steps := 2) -> void:
	if is_windows():
		_sendkey(175, steps)
	elif is_mac():
		OS.create_process("osascript", ["-e", "set volume output volume ((output volume of (get volume settings)) + %d)" % (steps * 6)])


func volume_down(steps := 2) -> void:
	if is_windows():
		_sendkey(174, steps)
	elif is_mac():
		OS.create_process("osascript", ["-e", "set volume output volume ((output volume of (get volume settings)) - %d)" % (steps * 6)])


func volume_mute() -> void:
	if is_windows():
		_sendkey(173, 1)
	elif is_mac():
		OS.create_process("osascript", ["-e", "set volume output muted (not (output muted of (get volume settings)))"])


# ---------------------------------------------------------------- 視窗
func to_desktop() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func apply_window_mode() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	if App.test_mode and OS.get_cmdline_user_args().has("--windowed"):
		return
	if bool(App.settings.fullscreen):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func shutdown_pc(restart := false) -> void:
	if is_windows():
		OS.create_process("shutdown.exe", ["/r" if restart else "/s", "/t", "5"])
	elif is_mac():
		OS.create_process("osascript", ["-e", "tell app \"System Events\" to %s" % ("restart" if restart else "shut down")])

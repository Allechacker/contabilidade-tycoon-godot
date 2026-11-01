extends Node2D
# Contabilidade Tycoon (Godot 4.3) - Parte 1: mapa da cidade, escritorios e HUD

const S := 1.5
const WORLD_W := 1530.0
const OFFICES := [
    {"name": "Saleta alugada", "cap": 2, "cost": 0, "lv": 1, "x": 30.0, "w": 90.0, "h": 90.0, "color": "5f9ea0"},
    {"name": "Sala comercial", "cap": 4, "cost": 3000, "lv": 2, "x": 360.0, "w": 120.0, "h": 130.0, "color": "4f86b5"},
    {"name": "Escritório no centro", "cap": 7, "cost": 9000, "lv": 3, "x": 730.0, "w": 150.0, "h": 175.0, "color": "7b6cb3"},
    {"name": "Torre contábil", "cap": 11, "cost": 25000, "lv": 4, "x": 1100.0, "w": 180.0, "h": 225.0, "color": "c99a12"},
]
const HOUSE_X := [145.0, 205.0, 265.0, 510.0, 570.0, 630.0, 910.0, 970.0, 1030.0, 1330.0, 1390.0, 1450.0]
const HOUSE_COLORS := ["e7c9a9", "bcd4e6", "cfe3c3", "f0d1d1", "d9d2f0"]
const SKY_TOP := Color("0f1b3d")
const SKY_BOT := Color("2f4a7a")
const ROAD := Color("2a3340")
const WIN := Color("f5d98a")
const LOCK := Color("56627a")
const LOCKWIN := Color("6c7890")
const DOOR := Color("1c2433")
const GOLD := Color("e3b866")
const TEAL := Color("1c7c82")
const TXT := Color("e8eefc")
const MUT := Color("9fb0d0")
const PANEL := Color("18223f")

var ledger := {}
var xp := 0
var lv := 1
var rep := 50
var office_idx := 0
var scroll := 0.0
var selected := {}
var pressing := false
var moved := 0.0
var ground_y := 0.0
var buttons := []
var font: Font = ThemeDB.fallback_font


func _ready() -> void:
    post("caixa", "capital", 5000.0)
    get_viewport().size_changed.connect(queue_redraw)


func post(d: String, c: String, v: float) -> void:
    ledger[d] = float(ledger.get(d, 0.0)) + v
    ledger[c] = float(ledger.get(c, 0.0)) - v


func cash() -> float:
    return float(ledger.get("caixa", 0.0))


func fmt(n: float) -> String:
    var s := str(absi(roundi(n)))
    var out := ""
    while s.length() > 3:
        out = "." + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return ("-R$ " if n < 0.0 else "R$ ") + s + out


func xp_next() -> int:
    return 50 * lv * lv


func check_level() -> void:
    while xp >= xp_next():
        lv += 1


func house_count() -> int:
    return mini(int(OFFICES[office_idx]["cap"]), 12)


func max_scroll() -> float:
    return maxf(0.0, WORLD_W * S - get_viewport_rect().size.x)


func can_buy(i: int) -> bool:
    var o: Dictionary = OFFICES[i]
    return i == office_idx + 1 and lv >= int(o["lv"]) and cash() >= float(o["cost"])


func buy(i: int) -> void:
    if not can_buy(i):
        return
    post("imoveis", "caixa", float(OFFICES[i]["cost"]))
    office_idx = i
    scroll = clampf(float(OFFICES[i]["x"]) * S - 40.0, 0.0, max_scroll())


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            pressing = true
            moved = 0.0
        else:
            if pressing and moved < 12.0:
                _tap(event.position)
            pressing = false
    elif event is InputEventMouseMotion and pressing:
        moved += event.relative.length()
        scroll = clampf(scroll - event.relative.x, 0.0, max_scroll())
        queue_redraw()


func _tap(p: Vector2) -> void:
    for b in buttons:
        if b["r"].has_point(p):
            _press(b["id"])
            queue_redraw()
            return
    var w := Vector2((p.x + scroll) / S, (p.y - ground_y) / S)
    selected = {}
    for i in OFFICES.size():
        var o: Dictionary = OFFICES[i]
        if Rect2(float(o["x"]), -float(o["h"]) - 8.0, float(o["w"]), float(o["h"]) + 8.0).has_point(w):
            selected = {"k": "o", "i": i}
    for i in house_count():
        if Rect2(float(HOUSE_X[i]) - 5.0, -70.0, 62.0, 70.0).has_point(w):
            selected = {"k": "c", "i": i}
    queue_redraw()


func _press(id: String) -> void:
    if id == "buy":
        buy(int(selected["i"]))
    elif id == "cash":
        post("caixa", "capital", 5000.0)
    elif id == "xp":
        xp += 100
        check_level()


func _draw() -> void:
    var size := get_viewport_rect().size
    ground_y = size.y * 0.42
    buttons.clear()
    draw_rect(Rect2(0, 0, size.x, ground_y * 0.6), SKY_TOP)
    draw_rect(Rect2(0, ground_y * 0.6, size.x, ground_y * 0.4 + 1.0), SKY_BOT)
    draw_set_transform(Vector2(-scroll, ground_y), 0.0, Vector2(S, S))
    draw_rect(Rect2(0, 0, WORLD_W, 60), ROAD)
    for i in OFFICES.size():
        _draw_office(i)
    for i in 12:
        _draw_house(i, i < house_count())
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    draw_rect(Rect2(0, ground_y + 60.0 * S, size.x, size.y), Color("0d1426"))
    _draw_hud(size)
    _draw_info(size)


func _draw_office(i: int) -> void:
    var o: Dictionary = OFFICES[i]
    var own := i <= office_idx
    var x: float = o["x"]
    var w: float = o["w"]
    var h: float = o["h"]
    var body := Color(String(o["color"])) if own else LOCK
    draw_rect(Rect2(x, -h, w, h), body)
    draw_rect(Rect2(x - 4, -h - 8, w + 8, 10), DOOR)
    var rows := int((h - 50.0) / 34.0)
    var cols := int((w - 16.0) / 30.0)
    for r in rows:
        for c in cols:
            draw_rect(Rect2(x + 12 + c * 30, -h + 14 + r * 34, 16, 20), WIN if own else LOCKWIN)
    draw_rect(Rect2(x + w / 2 - 10, -26, 20, 26), DOOR)
    if not own:
        var cx := x + w / 2
        var cy := -h / 2
        draw_rect(Rect2(cx - 11, cy, 22, 18), TXT)
        draw_arc(Vector2(cx, cy), 8.0, PI, TAU, 16, TXT, 3.0)
    if i == office_idx:
        draw_line(Vector2(x + w / 2, -h - 8), Vector2(x + w / 2, -h - 38), DOOR, 3.0)
        draw_colored_polygon(PackedVector2Array([Vector2(x + w / 2, -h - 38), Vector2(x + w / 2 + 28, -h - 30), Vector2(x + w / 2, -h - 22)]), GOLD)
    if selected.get("k", "") == "o" and int(selected["i"]) == i:
        draw_rect(Rect2(x - 3, -h - 11, w + 6, h + 11), GOLD, false, 3.0)
    draw_string(font, Vector2(x - 20, 24), String(o["name"]), HORIZONTAL_ALIGNMENT_CENTER, w + 40, 13, MUT)


func _draw_house(i: int, built: bool) -> void:
    var x: float = HOUSE_X[i]
    if not built:
        draw_rect(Rect2(x, -30, 52, 30), Color(1, 1, 1, 0.18), false, 1.5)
        return
    var shop := i % 2 == 1
    var h := 50.0 if shop else 40.0
    draw_rect(Rect2(x, -h, 52, h), Color(String(HOUSE_COLORS[i % 5])))
    if shop:
        draw_rect(Rect2(x - 3, -h, 58, 14), TEAL)
    else:
        draw_colored_polygon(PackedVector2Array([Vector2(x - 5, -h), Vector2(x + 26, -h - 24), Vector2(x + 57, -h)]), Color("7a5a48"))
    draw_rect(Rect2(x + 34, -24, 12, 24), DOOR)
    draw_rect(Rect2(x + 8, -h + 20, 20, 16), WIN)
    var b := Vector2(x + 26, -h - (14.0 if shop else 38.0))
    draw_circle(b, 10.0, GOLD)
    draw_string(font, b + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DOOR)
    if selected.get("k", "") == "c" and int(selected["i"]) == i:
        draw_rect(Rect2(x - 3, -h - 3, 58, h + 3), GOLD, false, 3.0)


func _box(r: Rect2, c: Color) -> void:
    draw_rect(r, c)


func _txt(p: Vector2, s: String, sz: int, c: Color) -> void:
    draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _draw_hud(size: Vector2) -> void:
    var bw := (size.x - 40.0) / 3.0
    _box(Rect2(10, 10, bw, 74), PANEL)
    _txt(Vector2(22, 36), "Caixa", 15, MUT)
    _txt(Vector2(22, 68), fmt(cash()), 24, GOLD)
    _box(Rect2(20 + bw, 10, bw, 74), PANEL)
    _txt(Vector2(32 + bw, 36), "Nível %d" % lv, 15, MUT)
    _txt(Vector2(32 + bw, 68), "%d XP" % xp, 24, TXT)
    var prev := 50 * (lv - 1) * (lv - 1)
    var frac := clampf(float(xp - prev) / float(xp_next() - prev), 0.0, 1.0)
    _box(Rect2(32 + bw, 74, bw - 24, 5), Color("0d1426"))
    _box(Rect2(32 + bw, 74, (bw - 24) * frac, 5), TEAL)
    _box(Rect2(30 + 2 * bw, 10, bw, 74), PANEL)
    _txt(Vector2(42 + 2 * bw, 36), "Reputação", 15, MUT)
    _txt(Vector2(42 + 2 * bw, 68), str(rep), 24, TXT)


func _button(r: Rect2, label: String, id: String, on: bool) -> void:
    _box(r, TEAL if on else Color("33405f"))
    draw_string(font, Vector2(r.position.x, r.position.y + r.size.y / 2 + 7), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, TXT if on else MUT)
    if on:
        buttons.append({"r": r, "id": id})


func _draw_info(size: Vector2) -> void:
    var top := ground_y + 60.0 * S + 24.0
    _box(Rect2(10, top, size.x - 20, 250), PANEL)
    var x := 28.0
    var y := top + 36.0
    if selected.is_empty():
        _txt(Vector2(x, y), "Arraste para os lados para ver a cidade.", 18, TXT)
        _txt(Vector2(x, y + 30), "Toque em um prédio ou casa.", 16, MUT)
    elif selected["k"] == "c":
        _txt(Vector2(x, y), "Casa de cliente", 22, TXT)
        _txt(Vector2(x, y + 32), "Os pedidos de lançamento entram na parte 2.", 16, MUT)
    else:
        var i := int(selected["i"])
        var o: Dictionary = OFFICES[i]
        _txt(Vector2(x, y), String(o["name"]), 22, TXT)
        _txt(Vector2(x, y + 28), "Atende até %d clientes" % int(o["cap"]), 16, MUT)
        if i <= office_idx:
            _txt(Vector2(x, y + 60), "Seu escritório." if i == office_idx else "Imóvel seu.", 18, GOLD)
        else:
            var okl := lv >= int(o["lv"])
            var okc := cash() >= float(o["cost"])
            _txt(Vector2(x, y + 60), ("[ok] " if okl else "[  ] ") + "Nível %d" % int(o["lv"]), 17, TXT if okl else MUT)
            _txt(Vector2(x, y + 86), ("[ok] " if okc else "[  ] ") + "Caixa de " + fmt(float(o["cost"])), 17, TXT if okc else MUT)
            _button(Rect2(x, y + 108, size.x - 56.0, 52), "Comprar escritório", "buy", can_buy(i))
    var ty := size.y - 76.0
    _button(Rect2(10, ty, (size.x - 30.0) / 2.0, 52), "TESTE: +R$ 5.000", "cash", true)
    _button(Rect2(20 + (size.x - 30.0) / 2.0, ty, (size.x - 30.0) / 2.0, 52), "TESTE: +100 XP", "xp", true)

--!nonstrict
-- Calendar quick-event capture and event viewer for Noctalia Launcher (/cal)

local function trDate(ms, allDay)
  local sec = math.floor(ms / 1000)
  if allDay then
    return noctalia.formatTime("%a, %d %b (Seharian)", sec)
  else
    return noctalia.formatTime("%a, %d %b %H:%M", sec)
  end
end

-- Smart parse query for date, time, and summary
local function parseInput(text)
  local str = text
  local today = noctalia.formatTime("%Y-%m-%d")
  local nowSec = math.floor(noctalia.nowMs() / 1000)
  local tomorrow = noctalia.formatTime("%Y-%m-%d", nowSec + 86400)
  local lusa = noctalia.formatTime("%Y-%m-%d", nowSec + 172800)

  local date = today
  local time = "09:00"
  local isAllDay = false

  -- Check explicit ISO date YYYY-MM-DD
  local isoDate = str:match("(%d%d%d%d%-%d%d%-%d%d)")
  if isoDate then
    date = isoDate
    str = str:gsub("(%d%d%d%d%-%d%d%-%d%d)", "")
  else
    -- Check relative date keywords (case-insensitive)
    local lower = str:lower()
    if lower:find("%f[%a]besok%f[%A]") or lower:find("%f[%a]tomorrow%f[%A]") then
      date = tomorrow
      str = str:gsub("(?i)%f[%a]besok%f[%A]", ""):gsub("(?i)%f[%a]tomorrow%f[%A]", "")
    elseif lower:find("%f[%a]lusa%f[%A]") then
      date = lusa
      str = str:gsub("(?i)%f[%a]lusa%f[%A]", "")
    elseif lower:find("%f[%a]hari ini%f[%A]") or lower:find("%f[%a]today%f[%A]") then
      date = today
      str = str:gsub("(?i)%f[%a]hari ini%f[%A]", ""):gsub("(?i)%f[%a]today%f[%A]", "")
    end
  end

  -- Check time HH:MM
  local t = str:match("(%d%d?:%d%d)")
  if t then
    if #t == 4 then t = "0" .. t end
    time = t
    str = str:gsub("(%d%d?:%d%d)", "")
  elseif str:lower():find("seharian") or str:lower():find("all%-day") then
    time = "all-day"
    isAllDay = true
    str = str:gsub("(?i)seharian", ""):gsub("(?i)all%-day", "")
  end

  local summary = noctalia.string.trim(str)
  if summary == "" then
    summary = "Agenda Baru"
  end

  return {
    summary = summary,
    date = date,
    time = time,
    isAllDay = isAllDay
  }
end

function onQuery(query)
  local text = noctalia.string.trim(query)
  local rows = {}

  if text ~= "" then
    local p = parseInput(text)
    local timeLabel = p.isAllDay and "Seharian" or p.time
    table.insert(rows, {
      id = "quick:" .. p.summary .. "|" .. p.date .. "|" .. p.time,
      title = "Simpan: " .. p.summary,
      subtitle = "Tanggal: " .. p.date .. " · Waktu: " .. timeLabel .. " (Tekan Enter)",
      glyph = "calendar-plus",
    })

    table.insert(rows, {
      id = "gui_prefill:" .. p.summary .. "|" .. p.date,
      title = "Buka Form Input Lengkap...",
      subtitle = "Atur lokasi, durasi, dan catatan tambahan via dialog",
      glyph = "edit",
    })
  else
    table.insert(rows, {
      id = "gui",
      title = "Tambah Event / Tanda Baru",
      subtitle = "Buka formulir input dialog (Mod+Shift+C)",
      glyph = "calendar-plus",
    })

    table.insert(rows, {
      id = "open_cal",
      title = "Buka Kalender Noctalia",
      subtitle = "Lihat kalender & agenda di Control Center",
      glyph = "calendar",
    })
  end

  -- Load synced events
  local evs = noctalia.calendarEvents()
  if evs and #evs > 0 then
    local matches = {}
    for _, ev in ipairs(evs) do
      local score = 0
      if text ~= "" then
        score = noctalia.fuzzyScore(text, ev.title) or -100
      end
      if text == "" or score > -50 then
        table.insert(matches, { ev = ev, score = score })
      end
    end

    -- Sort upcoming by startMs
    table.sort(matches, function(a, b)
      if text ~= "" and a.score ~= b.score then
        return a.score > b.score
      end
      return a.ev.startMs < b.ev.startMs
    end)

    for i = 1, math.min(#matches, 6) do
      local ev = matches[i].ev
      local dateStr = trDate(ev.startMs, ev.allDay)
      local locStr = (ev.location and ev.location ~= "") and (" @ " .. ev.location) or ""
      table.insert(rows, {
        id = "event:" .. ev.id .. "|" .. ev.title,
        title = ev.title .. locStr,
        subtitle = dateStr .. " · Klik untuk hapus atau kelola",
        glyph = "calendar-event",
      })
    end
  end

  launcher.setResults(query, rows)
end

function onActivate(id)
  if id == "gui" then
    noctalia.runAsync({"noctalia-calendar-event", "--gui"})
    return
  end

  if id == "open_cal" then
    noctalia.runAsync({"noctalia", "msg", "panel-open", "control-center", "calendar"})
    return
  end

  local qSummary, qDate, qTime = id:match("^quick:(.+)%|(%d%d%d%d%-%d%d%-%d%d)%|(.+)$")
  if qSummary and qDate and qTime then
    noctalia.runAsync({"noctalia-calendar-event", qSummary, qDate, qTime}, function(res)
      if res.exitCode == 0 then
        noctalia.notify("Kalender Noctalia", "Event berhasil dibuat: " .. qSummary .. " (" .. qDate .. ")")
      else
        noctalia.notifyError("Kalender Noctalia", "Gagal membuat event: " .. (res.stderr or ""))
      end
    end)
    return
  end

  local gSummary, gDate = id:match("^gui_prefill:(.+)%|(%d%d%d%d%-%d%d%-%d%d)$")
  if gSummary and gDate then
    noctalia.runAsync({"noctalia-calendar-event", "--gui"})
    return
  end

  local evId, evTitle = id:match("^event:(.+)%|(.+)$")
  if evId and evTitle then
    -- Delete or manage prompt
    noctalia.runAsync({"noctalia-calendar-event", "-d", evTitle}, function(res)
      noctalia.notify("Kalender Noctalia", "Event dihapus: " .. evTitle)
    end)
    return
  end
end

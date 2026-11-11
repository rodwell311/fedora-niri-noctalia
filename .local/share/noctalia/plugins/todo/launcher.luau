--!nonstrict
-- To-Do List launcher provider for Noctalia (/todo)
-- Supports 3 categories:
--   1. once: Sekali melakukan
--   2. deadline: Sampai tanggal berapa
--   3. duration: Dilakukan berapa hari (Target/Habit tracker)

local TODO_FILE = noctalia.expandPath("~/.local/share/noctalia/todos.json")

local function parseIsoDate(s)
  if type(s) ~= "string" then return nil end
  local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if y and m and d then
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
  end
  return nil
end

local function daysDiff(targetDateStr, todayStr)
  local t1 = parseIsoDate(targetDateStr)
  local t2 = parseIsoDate(todayStr)
  if t1 and t2 then
    return math.floor((t1 - t2) / 86400 + 0.5)
  end
  return 0
end

local function loadTodos()
  local raw = noctalia.readFile(TODO_FILE)
  if raw == nil or raw == "" then
    return {}
  end
  local decoded = noctalia.json.decode(raw)
  if type(decoded) == "table" then
    return decoded
  end
  return {}
end

local function parseSmartQuery(text)
  local str = text
  local today = noctalia.formatTime("%Y-%m-%d")
  local nowSec = math.floor(noctalia.nowMs() / 1000)
  local tomorrow = noctalia.formatTime("%Y-%m-%d", nowSec + 86400)
  local lusa = noctalia.formatTime("%Y-%m-%d", nowSec + 172800)

  local detectedType = "once"
  local dueDate = nil
  local targetDays = 7

  -- 1. Check duration / habit pattern (e.g. "selama 14 hari", "7 hari", "target 30 hari")
  local dMatch = str:match("selama%s+(%d+)%s*hari") or str:match("target%s+(%d+)%s*hari") or str:match("target%s+(%d+)") or str:match("(%d+)%s*hari")
  if dMatch then
    detectedType = "duration"
    targetDays = tonumber(dMatch) or 7
    str = str:gsub("selama%s+(%d+)%s*hari", ""):gsub("target%s+(%d+)%s*hari", ""):gsub("target%s+(%d+)", ""):gsub("(%d+)%s*hari", "")
  end

  -- 2. Check deadline pattern (e.g. "deadline 2026-11-20", "sampai besok", "deadline besok")
  local isoDate = str:match("(%d%d%d%d%-%d%d%-%d%d)")
  if isoDate then
    detectedType = "deadline"
    dueDate = isoDate
    str = str:gsub("(%d%d%d%d%-%d%d%-%d%d)", "")
  else
    local lower = str:lower()
    if lower:find("sampai besok") or lower:find("deadline besok") then
      detectedType = "deadline"
      dueDate = tomorrow
      str = str:gsub("(?i)sampai besok", ""):gsub("(?i)deadline besok", "")
    elseif lower:find("sampai lusa") or lower:find("deadline lusa") then
      detectedType = "deadline"
      dueDate = lusa
      str = str:gsub("(?i)sampai lusa", ""):gsub("(?i)deadline lusa", "")
    elseif lower:find("sampai hari ini") or lower:find("deadline hari ini") then
      detectedType = "deadline"
      dueDate = today
      str = str:gsub("(?i)sampai hari ini", ""):gsub("(?i)deadline hari ini", "")
    end
  end

  -- Clean cleanup words
  str = str:gsub("(?i)%f[%a]deadline%f[%A]", ""):gsub("(?i)%f[%a]sampai%f[%A]", ""):gsub("(?i)%f[%a]target%f[%A]", ""):gsub("(?i)%f[%a]selama%f[%A]", "")
  local cleanTitle = noctalia.string.trim(str)
  if cleanTitle == "" then
    cleanTitle = "Tugas Baru"
  end

  return {
    title = cleanTitle,
    type = detectedType,
    dueDate = dueDate or noctalia.formatTime("%Y-%m-%d", nowSec + 7 * 86400),
    targetDays = targetDays
  }
end

function onQuery(query)
  local text = noctalia.string.trim(query)
  local rows = {}
  local todayStr = noctalia.formatTime("%Y-%m-%d")
  local allTodos = loadTodos()
  local hasCompleted = false

  for _, t in ipairs(allTodos) do
    if t.completed then
      hasCompleted = true
      break
    end
  end

  if text == "" then
    -- Header actions when empty
    table.insert(rows, {
      id = "gui",
      title = "Tambah Tugas / To-Do Baru",
      subtitle = "Pilih kategori: Sekali, Deadline, atau Target Hari (Mod+Shift+T)",
      glyph = "checkbox",
    })

    if hasCompleted then
      table.insert(rows, {
        id = "clear_completed",
        title = "Bersihkan Tugas yang Selesai",
        subtitle = "Hapus semua tugas yang telah tuntas dicentang",
        glyph = "trash",
      })
    end
  else
    -- Smart quick-save row
    local parsed = parseSmartQuery(text)
    if parsed.type == "duration" then
      table.insert(rows, {
        id = "add:duration|" .. parsed.title .. "|" .. tostring(parsed.targetDays),
        title = "Simpan [Target Hari]: " .. parsed.title,
        subtitle = "Target: " .. tostring(parsed.targetDays) .. " hari berturut-turut · Tekan Enter untuk simpan",
        glyph = "flame",
      })
    elseif parsed.type == "deadline" then
      table.insert(rows, {
        id = "add:deadline|" .. parsed.title .. "|" .. parsed.dueDate,
        title = "Simpan [Deadline]: " .. parsed.title,
        subtitle = "Tenggat Waktu: " .. parsed.dueDate .. " · Tekan Enter untuk simpan",
        glyph = "clock",
      })
    else
      table.insert(rows, {
        id = "add:once|" .. parsed.title,
        title = "Simpan [Sekali Melakukan]: " .. parsed.title,
        subtitle = "Tugas tunggal sekali selesai · Tekan Enter untuk simpan",
        glyph = "checkbox",
      })
    end

    -- Alternative options
    table.insert(rows, {
      id = "gui_prefill:" .. parsed.title,
      title = "Buka Formulir: " .. parsed.title,
      subtitle = "Atur kategori spesifik dan tanggal secara leluasa via dialog GUI",
      glyph = "edit",
    })
  end

  -- List existing tasks
  local matches = {}
  for _, t in ipairs(allTodos) do
    local score = 0
    if text ~= "" then
      score = noctalia.fuzzyScore(text, t.title) or -100
    end
    if text == "" or score > -60 then
      table.insert(matches, { task = t, score = score })
    end
  end

  -- Sort: uncompleted first, then urgency
  table.sort(matches, function(a, b)
    if a.task.completed ~= b.task.completed then
      return not a.task.completed
    end
    if text ~= "" and a.score ~= b.score then
      return a.score > b.score
    end
    -- Category priority: deadline first
    if a.task.category ~= b.task.category then
      if a.task.category == "deadline" then return true end
      if b.task.category == "deadline" then return false end
    end
    return false
  end)

  for i = 1, math.min(#matches, 10) do
    local t = matches[i].task
    local cat = t.category or "once"
    local glyph = "circle"
    local sub = ""
    local titlePrefix = ""

    if t.completed then
      glyph = "circle-check"
      titlePrefix = "[Selesai] "
    end

    if cat == "deadline" then
      if not t.completed then
        glyph = "clock"
      end
      local diff = daysDiff(t.due_date, todayStr)
      local statusText = ""
      if diff > 0 then
        statusText = "Sisa " .. tostring(diff) .. " hari"
      elseif diff == 0 then
        statusText = "Jatuh tempo HARI INI!"
      else
        statusText = "Terlambat " .. tostring(-diff) .. " hari!"
      end
      sub = "[Deadline: " .. (t.due_date or "-") .. "] " .. statusText .. " · Klik untuk centang"
    elseif cat == "duration" then
      if not t.completed then
        glyph = "flame"
      end
      local cur = t.progress_days or 0
      local tot = t.target_days or 7
      local checkStatus = ""
      if t.completed then
        checkStatus = "Target " .. tostring(tot) .. " hari TERCAPAI"
      elseif t.last_checkin == todayStr then
        checkStatus = "Hari ini sudah check-in"
      else
        checkStatus = "Hari ini belum check-in!"
      end
      titlePrefix = "[" .. tostring(cur) .. "/" .. tostring(tot) .. " Hari] "
      sub = "[Target Hari] " .. checkStatus .. " · Klik untuk progress (+1 hari)"
    else
      if not t.completed then
        glyph = "circle"
      end
      sub = "[Sekali Melakukan] Klik untuk tandai selesai"
    end

    table.insert(rows, {
      id = "toggle:" .. t.id,
      title = titlePrefix .. t.title,
      subtitle = sub,
      glyph = glyph,
    })
  end

  launcher.setResults(query, rows)
end

function onActivate(id)
  if id == "gui" then
    noctalia.runAsync({"noctalia-todo", "--gui"})
    return
  end

  if id == "clear_completed" then
    noctalia.runAsync({"noctalia-todo", "--clear-completed"}, function(res)
      noctalia.notify("To-Do Noctalia", "Tugas yang selesai telah dibersihkan.")
    end)
    return
  end

  local toggleId = id:match("^toggle:(.+)$")
  if toggleId then
    noctalia.runAsync({"noctalia-todo", "-c", toggleId}, function(res)
      if res.exitCode == 0 then
        local line = noctalia.string.trim(res.stdout or "")
        noctalia.notify("To-Do Noctalia", line ~= "" and line or "Status tugas diperbarui.")
      end
    end)
    return
  end

  local addOnce = id:match("^add:once%|(.+)$")
  if addOnce then
    noctalia.runAsync({"noctalia-todo", addOnce, "--type", "once"}, function(res)
      if res.exitCode == 0 then
        noctalia.notify("To-Do Noctalia", "Tugas Sekali ditambahkan: " .. addOnce)
      end
    end)
    return
  end

  local addDeadTitle, addDueDate = id:match("^add:deadline%|(.+)%|(.+)$")
  if addDeadTitle and addDueDate then
    noctalia.runAsync({"noctalia-todo", addDeadTitle, "--type", "deadline", "--due", addDueDate}, function(res)
      if res.exitCode == 0 then
        noctalia.notify("To-Do Noctalia", "Tugas Deadline (" .. addDueDate .. ") ditambahkan: " .. addDeadTitle)
      end
    end)
    return
  end

  local addDurTitle, addDays = id:match("^add:duration%|(.+)%|(.+)$")
  if addDurTitle and addDays then
    noctalia.runAsync({"noctalia-todo", addDurTitle, "--type", "duration", "--days", addDays}, function(res)
      if res.exitCode == 0 then
        noctalia.notify("To-Do Noctalia", "Target " .. addDays .. " Hari ditambahkan: " .. addDurTitle)
      end
    end)
    return
  end

  local preTitle = id:match("^gui_prefill:(.+)$")
  if preTitle then
    noctalia.runAsync({"noctalia-todo", "--gui"})
    return
  end
end

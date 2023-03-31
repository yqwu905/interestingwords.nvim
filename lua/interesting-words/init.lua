local api = vim.api
local fn = vim.fn
local uv = vim.loop

local m = {}

m.words = {}
m.colors = {}
m.limits = {}

local get_default_config = function()
    return {
        colors = { '#aeee00', '#ff0000', '#0000ff', '#b88823', '#ffa724', '#ff2c4b' },
        search_count = true,
        navigation = true,
        search_key = "<leader>m",
        cancel_search_key = "<leader>M",
        color_key = "<leader>k",
        cancel_color_key = "<leader>K",
    }
end

local init_colors = function()
    for i, v in pairs(m.config.colors) do
        local color = "InterestingWord" .. i

        api.nvim_set_hl(0, color, { bg = v, fg = 'Black' })
        m.colors[color] = 595129 + i
    end
    m.limits.min = 595129 + 1
    m.limits.max = 595129 + #m.config.colors
end

local get_reg_ex = function(word)
    if vim.o.ignorecase and (not vim.o.smartcase or fn.match(word, "\\u") == -1) then
        return "\\c\\V" .. word
    else
        return "\\C\\V" .. word
    end
end

local get_visual_selection = function()
    local lines
    local start_row, start_col = fn.getpos("v")[2], fn.getpos("v")[3]
    local end_row, end_col = fn.getpos(".")[2], fn.getpos(".")[3]
    if end_row < start_row then
        start_row, end_row = end_row, start_row
        start_col, end_col = end_col, start_col
    elseif end_row == start_row and end_col < start_col then
        start_col, end_col = end_col, start_col
    end
    start_row = start_row - 1
    start_col = start_col - 1
    end_row = end_row - 1
    if api.nvim_get_mode().mode == 'V' then
        lines = api.nvim_buf_get_text(0, start_row, 0, end_row, -1, {})
    elseif api.nvim_get_mode().mode == 'v' then
        lines = api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
    end
    if lines == nil then
        return ""
    end

    local line = ""
    for i, v in ipairs(lines) do
        if i == 1 then
            line = line .. fn.escape(v, "\\")
        else
            line = line .. "\\n" .. fn.escape(v, "\\")
        end
    end

    return line
end

local get_rest_color = function()
    local res = {}
    for k, v in pairs(m.colors) do
        if v ~= 0 then
            table.insert(res, { color = k, mid = v })
        end
    end
    if #res == 0 then
        return nil
    end

    return res[math.random(#res)]
end

local color = function(word)
    local color = get_rest_color()
    if not color then
        vim.notify("InterestingWords: max number of highlight groups reached")
        return
    end

    m.words[word] = {}
    m.words[word].color = color.color
    m.words[word].mid = color.mid
    m.colors[color.color] = 0

    for i = 1, fn.winnr('$') do
        pcall(function()
            fn.matchadd(m.words[word].color, word, 1, m.words[word].mid, { window = i })
        end)
    end
end

local uncolor = function(word)
    if m.words[word] then
        for i = 1, fn.winnr('$') do
            pcall(function()
                fn.matchdelete(m.words[word].mid, i)
            end)
        end
        m.colors[m.words[word].color] = m.words[word].mid
        m.words[word] = nil
    end
end

local recolorAllWords = function()
    for k, v in pairs(m.words) do
        pcall(function()
            fn.matchadd(v.color, k, 1, v.mid, { window = 0 })
        end)
    end
end

local nearest_word_at_cursor = function()
    for _, match_item in pairs(fn.getmatches()) do
        if match_item.id >= m.limits.min or match_item.id <= m.limits.max then
            local buf_content = fn.join(api.nvim_buf_get_lines(0, 0, -1, {}), "\n")
            local cur_pos = #fn.join(api.nvim_buf_get_lines(0, 0, fn.line('.') - 1, {}), "\n")
                + ((fn.line('.') == 1) and 0 or 1) + fn.col('.') - 1
            local lst_pos = 0
            while true do
                local mat_pos = fn.matchstrpos(buf_content, match_item.pattern, lst_pos, 1)
                if mat_pos[1] == "" then
                    break
                end
                if cur_pos >= mat_pos[2] and cur_pos < mat_pos[3] then
                    return match_item.pattern
                end
                lst_pos = mat_pos[3]
            end
        end
    end
end

local filter = function(word)
    return string.sub(word, 5, -1)
end

local display_search_count = function(word, count)
    local icon = ''
    m.search_count_extmark_id = api.nvim_buf_set_extmark(0, m.search_count_namespace, fn.line('.') - 1, 0, {
        virt_text_pos = 'eol',
        virt_text = {
            { icon .. count, "Comment" },
        },
        hl_mode = 'combine',
    })
    m.search_count_cache = icon .. ' ' .. filter(word) .. count
    m.search_count_timer:again()
end

local hide_search_count = function(bufnr)
    api.nvim_buf_del_extmark(bufnr, m.search_count_namespace, m.search_count_extmark_id)
end

local scroll_timer = vim.loop.new_timer()
local function scroll_up(cnt)
    return vim.cmd("normal! " .. cnt .. "")
end

local function scroll_down(cnt)
    return vim.cmd("normal! " .. cnt .. "")
end

local function stop_scrolling()
    scroll_timer:stop()
end

local scroll_to_center = function()
    local window_height = api.nvim_win_get_height(0)
    local lines = fn.winline() - math.ceil(window_height / 2)
    if lines == 0 then
        return
    end
    local up = lines > 0
    lines = math.abs(lines)

    local each_time = function()
        local t = 200
        for _ = 1, lines do
            t = t - math.floor(t * 0.25 / (math.floor(lines / 10) + 1))
        end

        return t
    end
    local fixed_time = each_time()

    local scroll_callback = function()
        local cnt = 1
        if lines == 0 then
            stop_scrolling()
            return
        else
            cnt = math.floor(lines / 10) + 1
            lines = lines - cnt
        end

        if up then
            scroll_up(cnt)
        else
            scroll_down(cnt)
        end
    end

    scroll_timer:start(fixed_time, fixed_time, vim.schedule_wrap(scroll_callback))
end

m.lualine_get = function()
    return m.search_count_cache
end

m.lualine_has = function()
    return m.search_count_cache ~= ""
end

m.init_search_count = function()
    m.search_count_extmark_id = 0
    m.search_count_namespace = api.nvim_create_namespace('custom/search_count')
    m.search_count_timer = vim.loop.new_timer()
    m.search_count_timer:start(0, 5000, function()
        m.search_count_cache = ""
        vim.defer_fn(function()
                hide_search_count(0)
            end,
            100
        )
        m.search_count_timer:stop()
    end)

    vim.api.nvim_create_autocmd(
        { "CmdlineLeave" },
        {
            pattern = { "*" },
            callback = function(event)
                if vim.v.event.abort then
                    return
                end
                if event.match == "/" or event.match == "?" then
                    vim.defer_fn(function()
                        local searched = m.search_count(fn.getreg('/'))
                        if searched then
                            scroll_to_center()
                        end
                    end, 100)
                end
            end,
        }
    )
end

m.search_count = function(word)
    hide_search_count(0)
    if word == "" then
        return false
    end

    local cur_cnt = 0
    local total_cnt = 0
    local buf_content = fn.join(api.nvim_buf_get_lines(0, 0, -1, {}), "\n")
    local cur_pos = #fn.join(api.nvim_buf_get_lines(0, 0, fn.line('.') - 1, {}), "\n")
        + ((fn.line('.') == 1) and 0 or 1) + fn.col('.') - 1
    local lst_pos = 0
    while true do
        local mat_pos = fn.matchstrpos(buf_content, word, lst_pos, 1)
        if mat_pos[1] == "" then
            break
        end
        total_cnt = total_cnt + 1
        if cur_pos >= mat_pos[2] and cur_pos < mat_pos[3] then
            cur_cnt = total_cnt
        end
        lst_pos = mat_pos[3]
    end

    if total_cnt == 0 or cur_cnt == 0 then
        return false
    end

    local count = ' [' .. cur_cnt .. '/' .. total_cnt .. ']'
    display_search_count(word, count)

    return true
end

m.NavigateToWord = function(forward)
    local word = nearest_word_at_cursor()
    if not word then
        word = fn.getreg('/')
    end
    if word == "" then
        return
    end

    local search_flag = ''
    if not forward then
        search_flag = 'b'
    end
    local n = fn.search(word, search_flag)
    if n ~= 0 then
        scroll_to_center()
    else
        vim.notify("Pattern not found: " .. filter(word))
        return
    end

    if m.config.search_count then
        m.search_count(word)
    end
end

m.InterestingWord = function(mode, search)
    local word = ''
    if mode == 'v' then
        word = get_visual_selection()
    else
        word = '\\<' .. fn.expand('<cword>') .. '\\>'
    end
    if #word == 0 then
        return
    end
    word = get_reg_ex(word)

    if search then
        if word == fn.getreg('/') then
            fn.setreg('/', '')
            word = ''
        else
            fn.setreg('/', word)
            vim.cmd("set hls")
        end
    else
        if m.words[word] then
            uncolor(word)
            word = ''
        else
            color(word)
        end
    end

    if m.config.search_count then
        m.search_count(word)
    end
end

m.UncolorAllWords = function(search)
    m.search_count('')
    if search then
        fn.setreg('/', '')
    else
        for _, v in pairs(m.words) do
            for i = 1, fn.winnr('$') do
                pcall(function()
                    fn.matchdelete(v.mid, i)
                end)
            end
            m.colors[v.color] = v.mid
        end

        m.words = {}
    end
end

m.setup = function(opt)
    opt = opt or {}
    m.config = vim.tbl_deep_extend('force', get_default_config(), opt)

    init_colors()
    math.randomseed(uv.now())

    local group = api.nvim_create_augroup("InterestingWordsGroup", { clear = true })
    api.nvim_create_autocmd(
        { "WinEnter" },
        {
            callback = function()
                recolorAllWords()
                for i = 1, fn.winnr('$') do
                    hide_search_count(api.nvim_win_get_buf(fn.win_getid(i)))
                end
            end,
            group = group,
        }
    )

    if m.config.navigation then
        vim.keymap.set("n", "n", function() m.NavigateToWord(true) end,
            { noremap = true, silent = true })
        vim.keymap.set("n", "N", m.NavigateToWord, { noremap = true, silent = true })
    end

    if m.config.search_key then
        vim.keymap.set('n', m.config.search_key, function()
            m.InterestingWord('n', true)
        end, { noremap = true, silent = true })
        vim.keymap.set('x', m.config.search_key, function()
            m.InterestingWord('v', true)
        end, { noremap = true, silent = true })
        vim.keymap.set('n', m.config.cancel_search_key, function()
            m.UncolorAllWords(true)
        end, { noremap = true, silent = true })
    end

    if m.config.color_key then
        vim.keymap.set("n", m.config.color_key, function()
            m.InterestingWord('n', false)
        end, { noremap = true, silent = true })
        vim.keymap.set("x", m.config.color_key, function()
            m.InterestingWord('v', false)
        end, { noremap = true, silent = true })
        vim.keymap.set("n", m.config.cancel_color_key, function()
            m.UncolorAllWords()
        end, { noremap = true, silent = true })
    end

    if m.config.search_count then
        m.init_search_count()
    end
end

return m

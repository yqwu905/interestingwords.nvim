" --------------------------------------------------------------------
" This plugin was inspired and based on Steve Losh's interesting words
" .vimrc config https://www.youtube.com/watch?v=xZuy4gBghho
" --------------------------------------------------------------------

let s:interestingWordsGUIColors = ['#aeee00', '#ff0000', '#0000ff', '#b88823', '#ffa724', '#ff2c4b']
let s:interestingWordsTermColors = ['154', '121', '211', '137', '214', '222']

let g:interestingWordsGUIColors = exists('g:interestingWordsGUIColors') ? g:interestingWordsGUIColors : s:interestingWordsGUIColors
let g:interestingWordsTermColors = exists('g:interestingWordsTermColors') ? g:interestingWordsTermColors : s:interestingWordsTermColors

let s:hasBuiltColors = 0

let s:interestingWords = []
let s:interestingModes = []
let s:mids = {}
let s:recentlyUsed = []

function! ColorWord(word, mode)
  if !(s:hasBuiltColors)
    call s:buildColors()
  endif

  " gets the lowest unused index
  let l:n = index(s:interestingWords, 0)
  if (l:n == -1)
    if !(exists('g:interestingWordsCycleColors') && g:interestingWordsCycleColors)
      echom "InterestingWords: max number of highlight groups reached " . len(s:interestingWords)
      return
    else
      let l:n = s:recentlyUsed[0]
      call UncolorWord(s:interestingWords[n])
    endif
  endif

  let l:mid = 595129 + l:n
  let s:interestingWords[n] = a:word
  let s:interestingModes[n] = a:mode
  let s:mids[a:word] = l:mid

  call s:apply_color_to_word(l:n, a:word, a:mode, mid)

  call s:markRecentlyUsed(l:n)

endfunction

function! s:apply_color_to_word(n, word, mode, mid)
  let l:case = s:checkIgnoreCase(a:word) ? '\c' : '\C'
  let l:pat = ''
  if a:mode == 'v'
    let l:pat = l:case . '\V' . a:word
  else
    let l:pat = l:case . '\V\<' . escape(a:word, '\') . '\>'
  endif

  try
    let l:winnr = 1
    while l:winnr <= winnr("$")
      call matchadd("InterestingWord" . (a:n + 1), l:pat, 1, a:mid, {"window":l:winnr})
      let l:winnr += 1
    endwhile
  catch /E801/      " match id already taken.
  endtry
endfunction

function! s:nearest_group_at_cursor() abort
  let l:matches = {}
  for l:match_item in getmatches()
    let l:mids = filter(items(s:mids), 'v:val[1] == l:match_item.id')
    if len(l:mids) == 0
      continue
    endif
    let l:content = join(getline(1, '$'), "\n")
    let l:cur_pos = len(join(getline(1, line('.')-1), "\n")) + (line('.') != 1) + col('.') - 1
    let l:last_pos = 0
    while v:true
      let l:mat_pos = matchstrpos(l:content, l:match_item.pattern, l:last_pos, 1)
      if l:mat_pos[1] == -1
        break
      endif
      if l:cur_pos >= l:mat_pos[1] && l:cur_pos < l:mat_pos[2]
          return l:match_item.pattern
      endif
      let l:last_pos = l:mat_pos[2]
    endwhile
  endfor
  return ''
endfunction

function! UncolorWord(word)
  let l:index = index(s:interestingWords, a:word)
  if (l:index > -1)
    let l:mid = s:mids[a:word]
    let l:winnr = 1
    while l:winnr <= winnr("$")
      silent! call matchdelete(l:mid, l:winnr)
      let l:winnr += 1
    endwhile

    let s:interestingWords[index] = 0
    unlet s:mids[a:word]
  endif
endfunction

function! s:getmatch(mid) abort
  return filter(getmatches(), 'v:val.id==a:mid')[0]
endfunction

function! GetPickedWord()
  let l:currentWord = s:nearest_group_at_cursor()
  if len(l:currentWord) != 0
    return l:currentWord
  else
    return @/
  endif
endfunction

function! NavigateToWord(word, direction)
  if a:word == ''
    return
  endif

  let l:searchFlag = ''
  if !(a:direction)
    let l:searchFlag = 'b'
  endif
  let l:num = search(a:word, l:searchFlag)
  if l:num != 0
    normal! zz
  else
    echohl WarningMsg | echomsg "E486: Pattern not found: " . a:word
  endif
endfunction

function! InterestingWords(mode) range
  let l:currentWord = ''
  if a:mode == 'v'
    let l:currentWord = s:get_visual_selection()
  else
    let l:currentWord = expand('<cword>')
  endif
  if !(len(l:currentWord))
    return
  endif
  if (s:checkIgnoreCase(l:currentWord))
    let l:currentWord = tolower(l:currentWord)
  endif
  if (index(s:interestingWords, l:currentWord) == -1)
    call ColorWord(l:currentWord, a:mode)
  else
    call UncolorWord(l:currentWord)
  endif
endfunction

function! s:get_visual_selection()
  " Why is this not a built-in Vim script function?!
  let [l:row1, l:col1] = getpos("v")[1:2]
  let [l:row2, l:col2] = getpos(".")[1:2]
  if l:row2 < l:row1
    let l:tmp = l:row1
    let l:row1 = l:row2
    let l:row2 = l:tmp

    let l:tmp = l:col1
    let l:col1 = l:col2
    let l:col2 = l:tmp
  elseif l:row1 == l:row2 && l:col2 < l:col1
    let l:tmp = l:col1
    let l:col1 = l:col2
    let l:col2 = l:tmp
  endif
  let l:o_ignore = &ignorecase
  let l:lines = []
  set noignorecase
  if mode() == 'V'
    let l:lines = getline(l:row1, l:row2)
  elseif mode() == 'v'
    let l:lines = getline(l:row1, l:row2)
    let l:lines[-1] = l:lines[-1][: l:col2 - (&selection == 'inclusive' ? 1 : 2)]
    let l:lines[0] = l:lines[0][l:col1 - 1:]
  endif

  if l:o_ignore
    set ignorecase
  endif
  normal! 

  let l:line = ''
  let l:flag = 1
  for l:v in l:lines
    if l:flag == 1
      let l:line = l:line . escape(l:v, '\')
      let l:flag = 0
    else
      let l:line = l:line . '\n' . escape(l:v, '\')
    endif
  endfor

  return l:line
endfunction

function! UncolorAllWords()
  for l:word in s:interestingWords
    " check that word is actually a String since '0' is falsy
    if (type(l:word) == 1)
      call UncolorWord(l:word)
    endif
  endfor
endfunction

function! s:recolorAllWords()
  let l:i = 0
  for l:word in s:interestingWords
    if (type(l:word) == 1)
      let l:mode = s:interestingModes[l:i]
      let l:mid = s:mids[l:word]
      call s:apply_color_to_word(l:i, l:word, l:mode, l:mid)
    endif
    let l:i += 1
  endfor
endfunction

" returns true if the ignorecase flag needs to be used
function! s:checkIgnoreCase(word)
  " return false if case sensitive is used
  if (exists('g:interestingWordsCaseSensitive'))
    return !g:interestingWordsCaseSensitive
  endif
  " checks ignorecase
  " and then if smartcase is on, check if the word contains an uppercase char
  return &ignorecase && (!&smartcase || (match(a:word, '\u') == -1))
endfunction

" moves the index to the back of the s:recentlyUsed list
function! s:markRecentlyUsed(n)
  let l:index = index(s:recentlyUsed, a:n)
  call remove(s:recentlyUsed, l:index)
  call add(s:recentlyUsed, a:n)
endfunction

function! s:uiMode()
  " Stolen from airline's airline#init#gui_mode()
  return ((has('nvim') && exists('$NVIM_TUI_ENABLE_TRUE_COLOR') && !exists("+termguicolors"))
     \ || has('gui_running') || (has("termtruecolor") && &guicolors == 1) || (has("termguicolors") && &termguicolors == 1)) ?
      \ 'gui' : 'cterm'
endfunction

" initialise highlight colors from list of GUIColors
" initialise length of s:interestingWord list
" initialise s:recentlyUsed list
function! s:buildColors()
  if (s:hasBuiltColors)
    return
  endif
  let l:ui = s:uiMode()
  let l:wordColors = (l:ui == 'gui') ? g:interestingWordsGUIColors : g:interestingWordsTermColors
  if (exists('g:interestingWordsRandomiseColors') && g:interestingWordsRandomiseColors)
    " fisher-yates shuffle
    let l:i = len(l:wordColors)-1
    while l:i > 0
      let l:j = s:Random(l:i)
      let l:temp = l:wordColors[l:i]
      let l:wordColors[i] = l:wordColors[l:j]
      let l:wordColors[j] = l:temp
      let l:i -= 1
    endwhile
  endif
  " select ui type
  " highlight group indexed from 1
  let l:currentIndex = 1
  for l:wordColor in l:wordColors
    execute 'hi! def InterestingWord' . l:currentIndex . ' ' . l:ui . 'bg=' . l:wordColor . ' ' . l:ui . 'fg=Black'
    call add(s:interestingWords, 0)
    call add(s:interestingModes, 'n')
    call add(s:recentlyUsed, l:currentIndex-1)
    let l:currentIndex += 1
  endfor
  let s:hasBuiltColors = 1
endfunc

" helper function to get random number between 0 and n-1 inclusive
function! s:Random(n)
  let l:timestamp = reltimestr(reltime())[-2:]
  return float2nr(floor(a:n * l:timestamp/100))
endfunction

if !exists('g:interestingWordsDefaultMappings') || g:interestingWordsDefaultMappings != 0
    let g:interestingWordsDefaultMappings = 1
endif

au WinEnter * call s:recolorAllWords()

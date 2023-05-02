if exists("g:loaded_interestingwords")
  finish
endif
let g:loaded_interestingwords = 1

command! -nargs=0 InteresingWordsJumpNext lua require('interestingwords').NavigateForward()
command! -nargs=0 InteresingWordsJumpPrev lua require('interestingwords').NavigateBackward()
command! -nargs=0 InteresingWordsNormalSearch lua require('interestingwords').SearchNormal()
command! -nargs=0 InteresingWordsVisualSearch lua require('interestingwords').SearchVisual()
command! -nargs=0 InteresingWordsClearHighlight lua require('interestingwords').UncolorAllWords()

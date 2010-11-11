function! tap#parse()
    0
    let b:tap_result = {}
    while search('^not ok \d\+', 'W') > 0
        echo matchlist(getline('.'), '^not ok \v(\d+) - (.+)$')
    endwhile
    0
endfunction

function! tap#run (...)
    let file = a:0 ? a:1 : expand('%')
    let command = 'perl ' . file

    new
    set buftype=nofile
    syntax match tapComment /#.*/
    syntax match tapOK      /^\(\s\{4}\)*ok /he=e-1 nextgroup=tapNr
    syntax match tapNG      /^\(\s\{4}\)*not ok /he=e-1 nextgroup=tapNr
    syntax match tapPlan    /^\(\s\{4}\)*[0-9]\+\.\.[0-9]\+$/
    syntax match tapNr      /[0-9]\+/ contained
    syntax match tapPASS    /^PASS\>/
    syntax match tapFAIL    /^FAIL\>/
    
    syntax region tapFold start=/\.\.\. $/ matchgroup=tapFoldDelim end=/^\(PASS\|FAIL\)---$/ transparent fold
    setlocal foldmethod=syntax

    autocmd BufHidden <buffer> bwipeout

    highlight tapOK      ctermfg=Green ctermbg=Black
    highlight tapNG      ctermfg=Red   ctermbg=Black
    highlight tapPASS    ctermfg=Black ctermbg=Green
    highlight tapFAIL    ctermfg=Black ctermbg=Red
    highlight link tapComment Comment
    highlight link tapNr      Number
    highlight link tapPlan    Number
    highlight link tapFoldDelim Ignore

    execute "normal! a\<C-R>=file\<CR> ... "
    redraw
    silent! execute 'read!' command
    normal! o---

    setlocal nomodifiable
    syntax sync fromstart

    call tap#parse()
endfunction

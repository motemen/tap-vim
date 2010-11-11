function! tap#parse(output)
    let result = { 'raw': a:output, 'failed': {} }
    for line in split(a:output, "\n")
        let m = matchlist(line, '^not ok \v(\d+) - (.+)')
        if len(m)
            let result.failed[m[1]] = { 'name': m[2] }
        endif
    endfor
    return result
endfunction

function! tap#run (command, file)
    "put =a:file . ' ... '
    put =a:file . ' ' . repeat('.', (len(a:file) / 16 + 1) * 16 + 3 - len(a:file)) . ' '
    normal! zt
    redraw
    let result = tap#parse(system(a:command))
    put =result.raw
    normal! o

    if len(keys(result.failed))
        normal! AFAIL ---
    else
        normal! APASS ---
    end
endfunction

function! tap#prove (...)
    let files = a:0 ? split(glob(a:1), "\0") : [ expand('%') ]

    new
    set buftype=nofile
    syntax match tapComment /#.*/
    syntax match tapOK      /^\(\s\{4}\)*ok /he=e-1 nextgroup=tapNr
    syntax match tapNG      /^\(\s\{4}\)*not ok /he=e-1 nextgroup=tapNr
    syntax match tapPlan    /^\(\s\{4}\)*[0-9]\+\.\.[0-9]\+$/
    syntax match tapNr      /[0-9]\+/ contained
    syntax match tapPASS    /^PASS\>/ contained
    syntax match tapFAIL    /^FAIL\>/ contained
    
    syntax region tapFold start=/\.\.\. $/ matchgroup=tapFoldDelim end=/ ---$/ transparent fold contains=tapOK,tapNG,tapPlan,tapComment,tapPASS,tapFAIL
    setlocal foldmethod=syntax
    setlocal foldtext=getline(v:foldstart).getline(v:foldend)

    autocmd BufHidden <buffer> bwipeout

    highlight tapOK      ctermfg=Green ctermbg=Black
    highlight tapNG      ctermfg=Red   ctermbg=Black
    highlight tapPASS    ctermfg=Black ctermbg=Green
    highlight tapFAIL    ctermfg=Black ctermbg=Red
    highlight link tapComment Comment
    highlight link tapNr      Number
    highlight link tapPlan    Number
    highlight link tapFoldDelim Ignore

    for file in files
        call tap#run('perl -Ilib ' . file, file)
        syntax sync fromstart
    endfor

    0d
    setlocal nomodifiable
    " %foldopen!
endfunction

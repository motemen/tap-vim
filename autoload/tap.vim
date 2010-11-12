function! tap#parse(output)
    let result = { 'raw': a:output, 'failed': {} }
    for line in split(a:output, "\n")
        let m = matchlist(line, '^not ok \v(\d+) - (.+)') " TODO not ok # TODO
        if len(m)
            let result.failed[m[1]] = { 'name': m[2] }
        endif
    endfor
    return result
endfunction

function! tap#run (command, file)
    execute line('.') == 1 ? 'put!' : 'put' "=a:file . ' ' . repeat('.', (len(a:file) / 32 + 1) * 32 + 3 - len(a:file)) . ' '"
    " normal! zt
    redraw
    let result = tap#parse(system(a:command))
    put =result.raw
    normal! o

    if len(keys(result.failed))
        normal! AFAIL ---
    else
        normal! APASS ---
    end
    normal! o
endfunction

function! tap#prove (...)
    let arg = a:0 ? a:1 : '%'
    let files = split(glob(arg), "\0")

    new
    autocmd BufUnload <buffer> bwipeout
    setlocal buftype=nofile foldmethod=syntax foldtext=getline(v:foldstart).(v:foldend-1<=v:foldstart?'....':getline(v:foldend-1))

    syntax match tapOK      /^\(\s\{4}\)*ok /he=e-1 nextgroup=tapNr
    syntax match tapNG      /^\(\s\{4}\)*not ok /he=e-1 nextgroup=tapNr
    syntax match tapPlan    /^\(\s\{4}\)*[0-9]\+\.\.[0-9]\+$/
    syntax match tapNr      /[0-9]\+/ contained
    syntax match tapPASS    /^PASS\>/ contained
    syntax match tapFAIL    /^FAIL\>/ contained
    syntax match tapComment /#.*/ contains=tapSkip,tapTODO
    syntax match tapSkip    /# skip /hs=s+1 contained
    syntax match tapSkip    /# TODO /hs=s+1 contained
    
    syntax region tapFold start=/\.\.\. $/ matchgroup=tapFoldDelim end=/ ---\n\n/ transparent fold contains=tapOK,tapNG,tapPlan,tapComment,tapPASS,tapFAIL

    highlight tapOK      ctermfg=Green ctermbg=Black
    highlight tapNG      ctermfg=Red   ctermbg=Black
    highlight tapPASS    ctermfg=Black ctermbg=Green
    highlight tapFAIL    ctermfg=Black ctermbg=Red

    highlight link tapNr        Number
    highlight link tapPlan      Number
    highlight link tapFoldDelim Ignore
    highlight link tapComment   Comment
    highlight link tapSkip      Statement
    highlight link tapTODO      Statement

    for file in files
        call tap#run('perl -Ilib ' . file, file) " TODO option
        syntax sync fromstart
    endfor

    setlocal nomodifiable
    " %foldopen! " TODO foldopen failed
endfunction

function! tap#parse (output)
    let result = { 'raw': a:output, 'failed': {}, 'messages': [] }
    for line in split(a:output, "\n")
        let m = matchlist(line, '^not ok \v(\d+)%( - ([^#]+))=%(.*# TODO)@!')
        if len(m)
            let result.failed[m[1]] = { 'name': m[2] }
        endif
    endfor

    let pos = -1
    let pat = 'not ok \d\+\%( - \([^#]\+\)\)\=\n#\s\{3}\(Failed test.\{-}\)\= at \(\S\+\) line \(\d\+\)\.'
    while 1
        let pos = match(a:output, pat, pos + 1)
        if pos == -1 | break | endif
        let [ name, message, file, line ] = matchlist(a:output, pat, pos)[1:4]

        let message = substitute(message, '\n#\s*', '', 'g')
        call add(result.messages, { 'name': name, 'message': message, 'file': file, 'line': line })
    endwhile

    return result
endfunction

function! tap#run (command, file)
    execute 'normal!' (line('.') == 1 ? 'C' : 'o') . a:file
                \ repeat('.', (len(a:file) / 32 + 1) * 32 + 3 - len(a:file)) ''

    redraw
    let result = tap#parse(system(a:command))
    if v:shell_error != 0
        let result.failed[-1] = 1 " TODO
    endif
    put =result.raw
    normal! o

    for m in result.messages
        call setqflist([ { 'filename': m.file, 'lnum': m.line, 'text': m.message } ], 'a')
    endfor

    if len(keys(result.failed))
        normal! AFAIL ---
    else
        normal! APASS ---
    end
    normal! o
endfunction

function! tap#setup_highlights ()
    syntax match tapNG   /^\(\s\{4}\)*not ok \(.\{-}# TODO\)\@!/he=e-1 nextgroup=tapNr
    syntax match tapOK   /^\(\s\{4}\)*ok \(.\{-}# \(TODO\|skip\)\)\@!/he=e-1 nextgroup=tapNr

    syntax match tapTODO /^\(\s\{4}\)*\(not \)\=ok \ze.\{-}# TODO /he=e-1 nextgroup=tapNr
    syntax match tapSkip /^\(\s\{4}\)*ok \ze.\{-}# skip /he=e-1 nextgroup=tapNr

    syntax match tapPlan    /^\(\s\{4}\)*[0-9]\+\.\.[0-9]\+$/
    syntax match tapNr      /[0-9]\+/ contained
    syntax match tapPASS    /^PASS\>/ contained
    syntax match tapFAIL    /^FAIL\>/ contained
    syntax match tapComment /#.*/ contains=tapCommentSkip,tapCommentTODO
    syntax match tapCommentSkip    /# skip /hs=s+1 contained
    syntax match tapCommentTODO    /# TODO /hs=s+1 contained
    
    syntax region tapFold start=/\.\.\. $/ matchgroup=tapFoldDelim end=/ ---\n\n/ transparent fold contains=tapOK,tapNG,tapPlan,tapComment,tapPASS,tapFAIL,tapTODO,tapSkip

    highlight tapOK      ctermfg=Green ctermbg=Black
    highlight tapNG      ctermfg=Red   ctermbg=Black
    highlight tapPASS    ctermfg=Black ctermbg=Green
    highlight tapFAIL    ctermfg=Black ctermbg=Red
    highlight tapTODO    ctermfg=DarkBlue ctermbg=Black
    highlight tapSkip    ctermfg=DarkBlue ctermbg=Black

    highlight link tapNr        Number
    highlight link tapPlan      Number
    highlight link tapFoldDelim Ignore
    highlight link tapComment   Comment
    highlight link tapCommentSkip      Statement
    highlight link tapCommentTODO      Statement
endfunction

function! tap#prove (...)
    let arg = a:0 ? a:1 : '%'
    let files = split(glob(isdirectory(arg) ? arg . '/**/*.t' : arg), "\0")

    let bufname = 'prove ' . arg
    if bufexists(bufname)
        let winnr = bufwinnr(bufname)
        if winnr == -1
            execute 'sbuffer' bufname
        else
            execute winnr 'wincmd' 'w'
        endif
        set modifiable
        %d
    else
        new
        setlocal buftype=nofile
        setlocal foldmethod=syntax foldtext=getline(v:foldstart).(v:foldend-1<=v:foldstart?'\ \ \ \ \ ':getline(v:foldend-1))
        execute 'file' escape(bufname, ' *%\')
        autocmd BufUnload <buffer> bwipeout
        call tap#setup_highlights()
    endif

    call setqflist([])

    for file in files
        call tap#run('perl -Ilib ' . file, file) " TODO option
        syntax sync fromstart
    endfor
    " normal! o

    silent! global/^FAIL ---$/normal! za
    0
    setlocal nomodifiable
endfunction

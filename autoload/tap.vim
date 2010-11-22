function! tap#parse (output)
    let result = { 'raw': a:output, 'tests': [] }

    let last_type = ''
    for line in split(a:output, "\n")
        let res = tap#parse_line(line)

        if res.type == 'test'
            call add(result.tests, res)
        elseif res.type == 'comment' && res.comment =~ '^ \{3}' && last_type == 'test'
            " only for Test::Builder diag

            if !exists('result.tests[-1].builder_diag')
                let result.tests[-1].builder_diag = ''
            endif

            let result.tests[-1].builder_diag .= ' ' . strpart(res.comment, 3)

            continue " do not set last_type
        endif

        let last_type = res.type
    endfor

    return result
endfunction

function! tap#parse_line (line)
    let [ indent, line ] = matchlist(a:line, '^\v(\s*)(.*)$')[1:2]

    let m_plan    = matchlist(line, '^\v(\d+)\.\.(\d+)$')
    let m_test    = matchlist(line, '^\v(not )?ok (\d+)%( - (.*))?%(# (.*))?')
    let m_comment = matchlist(line, '^\v#(.*)')

    let result = {}

    if len(m_plan)
        let [ s, e ] = m_plan[1:2]

        let result.type = 'plan'
        let result.tests_planned = e

    elseif len(m_test)
        let [ failed, number, description, pragma ] = m_test[1:4]
        let is_todo = pragma =~ '\<TODO\>'
        let is_skip = pragma =~ '\<skip\>'

        let result.type = 'test'
        let result.number = number
        let result.description = description
        let result.failed = len(failed) && !is_todo

    elseif len(m_comment)
        let [ comment ] = m_comment[1:1]

        let result.type = 'comment'
        let result.comment = comment
    
    else
        let result.type = 'unknown'

    endif

    return result
endfunction

function! tap#run (command, file)
    execute 'normal!' (line('.') == 1 ? 'C' : 'o') . a:file
                \ repeat('.', (len(a:file) / 32 + 1) * 32 + 3 - len(a:file)) ''

    redraw
    let result = tap#parse(system(a:command))
    let failed = 0
    if v:shell_error != 0
        let failed = 1
    endif
    put =result.raw
    normal! o

    for t in result.tests
        if t.failed && exists('t.builder_diag')
            let failed = 1
            let m = matchlist(t.builder_diag, '\vat (\f+) line (\d+)\.')
            if len(m)
                call setqflist([ { 'filename': m[1], 'lnum': m[2], 'text': t.builder_diag } ], 'a')
            endif
        endif
    endfor

    if failed
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
        " reuse buffer
        if getbufvar(bufname, '&buftype') != 'nofile'
            throw 'got wrong buffer'
        endif

        let winnr = bufwinnr(bufname)
        if winnr == -1
            execute 'sbuffer' bufname
        else
            execute winnr 'wincmd' 'w'
        endif

        setlocal modifiable
        %delete
    else
        new
        setlocal buftype=nofile
        setlocal foldmethod=syntax foldtext=getline(v:foldstart).(v:foldend-1<=v:foldstart?'\ \ \ \ \ ':getline(v:foldend-1))
        execute 'file' escape(bufname, ' *%\')
        autocmd BufUnload <buffer> bwipeout
        call tap#setup_highlights()
    endif

    call setqflist([])

    " TODO BAIL_OUT
    for file in files
        let command = 'perl -Ilib ' " TODO option

        let line = join(readfile(file, '', 1))
        let opt_taint = matchstr(line, '^#!.*\<perl.*\s\zs-[Tt]\+')
        if len(opt_taint)
            let command .= ' ' . opt_taint
        endif

        call tap#run(command . ' ' . file, file)
        syntax sync fromstart
    endfor
    " normal! o

    silent! global/^FAIL ---$/normal! za
    0
    setlocal nomodifiable
endfunction

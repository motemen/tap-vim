function! tap#parse (output)
    let result = { 'raw': a:output, 'tests': [], 'tests_planned': -1, 'bailout': 0 }

    let last_type = ''
    for line in split(a:output, "\n")
        let res = tap#parse_line(line)

        if res.type == 'plan'
            let result.tests_planned = res.tests_planned
        elseif res.type == 'test'
            call add(result.tests, res)
        elseif res.type == 'comment' && res.comment =~ '^ \{3}' && last_type == 'test'
            " only for Test::Builder diag

            if !exists('result.tests[-1].builder_diag')
                let result.tests[-1].builder_diag = ''
            endif

            let result.tests[-1].builder_diag .= ' ' . strpart(res.comment, 3)

            continue " do not set last_type
        elseif res.type == 'bailout'
            let result.bailout = 1
        endif

        let last_type = res.type
    endfor

    return result
endfunction

function! tap#parse_line (line)
    let [ indent, line ] = matchlist(a:line, '^\v(\s*)(.*)$')[1:2]

    let m_plan    = matchlist(line, '^\v(\d+)\.\.(\d+)') " TODO comment
    let m_test    = matchlist(line, '^\v(not )?ok (\d+)%( - ([^#]*))?%(# (.*))?')
    let m_comment = matchlist(line, '^\v#(.*)')
    let m_bailout = matchlist(line, '^\vBail out!\s+(.*)')

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

    elseif len(m_bailout)
        let [ reason ] = m_bailout[1:1]

        let result.type = 'bailout'
        let result.reason = reason

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

    if result.tests_planned == 0
        normal! ASKIP ---
    elseif failed
        normal! AFAIL ---
    else
        normal! APASS ---
    end
    normal! o

    return result
endfunction

function! tap#setup_highlights ()
    syntax match tapTestOK   /^\(\s\{4}\)*ok \(.\{-}# \(TODO\|skip\)\)\@!/he=e-1 nextgroup=tapNr
    syntax match tapTestNG   /^\(\s\{4}\)*not ok \(.\{-}# TODO\)\@!/he=e-1 nextgroup=tapNr

    syntax match tapTestTODO /^\(\s\{4}\)*\(not \)\=ok \ze.\{-}# TODO /he=e-1 nextgroup=tapNr
    syntax match tapTestSkip /^\(\s\{4}\)*ok \ze.\{-}# skip /he=e-1 nextgroup=tapNr

    syntax match tapPlan    /^\(\s\{4}\)*[0-9]\+\.\.[0-9]\+/
    syntax match tapBailout /^Bail out!.*/
    syntax match tapNr      /[0-9]\+/ contained

    syntax match tapComment     /#.*/ contains=tapDirectiveTODOAndSkip,tapDirectiveSkip,tapDirectiveTODO
    syntax match tapDirectiveSkip /\c# SKIP /hs=s+1 contained
    syntax match tapDirectiveTODO /\c# TODO /hs=s+1 contained
    syntax match tapDirectiveTODOAndSkip /\c# TODO & SKIP /hs=s+1 contained

    syntax match tapResultPASS    /^PASS\>/ contained
    syntax match tapResultFAIL    /^FAIL\>/ contained
    syntax match tapResultSKIP    /^SKIP\>/ contained
    
    syntax region tapFold start=/\.\.\. $/ matchgroup=tapFoldDelim end=/ ---\n\n/ transparent fold contains=tapTestOK,tapTestNG,tapTestTODO,tapTestSkip,tapPlan,tapComment,tapResultPASS,tapResultFAIL,tapResultSKIP,tapBailout

    highlight tapTestOK   ctermfg=Green ctermbg=Black
    highlight tapTestNG   ctermfg=Red   ctermbg=Black
    highlight tapResultPASS ctermfg=Black ctermbg=Green
    highlight tapResultFAIL ctermfg=Black ctermbg=Red
    highlight tapResultSKIP ctermfg=Black ctermbg=Yellow

    highlight tapTestTODO ctermfg=DarkBlue ctermbg=Black
    highlight tapTestSkip ctermfg=DarkBlue ctermbg=Black

    highlight link tapNr        Number
    highlight link tapPlan      Number
    highlight link tapBailout   Error
    highlight link tapFoldDelim Ignore
    highlight link tapComment   Comment
    highlight link tapDirectiveSkip        Statement
    highlight link tapDirectiveTODO        Statement
    highlight link tapDirectiveTODOAndSkip Statement
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

        let result = tap#run(command . ' ' . file, file)
        syntax sync fromstart

        if result.bailout
            break
        endif
    endfor
    " normal! o

    silent! global/^FAIL ---$/normal! za
    0
    setlocal nomodifiable
endfunction

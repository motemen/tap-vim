function! tap#init_parse_result ()
    return { 'raw': '', 'tests': [], 'other_errors': [], 'tests_planned': -1, 'bailout': 0 }
endfunction

function! tap#parse (output)
    let result = tap#init_parse_result()

    for line in split(a:output, '\n')
        call tap#parse_line(line, result)
    endfor

    return result
endfunction

function! tap#parse_line (line, total_result)
    let [ indent, line ] = matchlist(a:line, '^\v(\s*)(.*)$')[1:2]

    let a:total_result.raw .= indent . line . "\n"

    let m_plan    = matchlist(line, '^\v(\d+)\.\.(\d+)') " TODO comment
    let m_test    = matchlist(line, '^\v(not )?ok (\d+)%( - ([^#]*))?%(# (.*))?')
    let m_comment = matchlist(line, '^\v#(.*)')
    let m_bailout = matchlist(line, '^\vBail out!\s+(.*)')
    let m_error   = matchlist(line, '^\v(.+) at (\f+) line (\d+)\.$')

    let result = {}

    if len(m_plan)
        let [ s, e ] = m_plan[1:2]

        let result.type = 'plan'
        let result.tests_planned = e
        let a:total_result.tests_planned = result.tests_planned

    elseif len(m_test)
        let [ failed, number, description, pragma ] = m_test[1:4]
        let is_todo = pragma =~ '\<TODO\>'
        let is_skip = pragma =~ '\<skip\>'

        let result.type = 'test'
        let result.number = number
        let result.description = description
        let result.failed = len(failed) && !is_todo

        if result.failed
            let a:total_result.failed = 1
        endif

        call add(a:total_result.tests, result)

    elseif len(m_comment)
        let [ comment ] = m_comment[1:1]

        let result.type = 'comment'
        let result.comment = comment

        if result.comment =~ '^ \{3}' && a:total_result.last_type == 'test'
            " only for Test::Builder diag

            if !exists('a:total_result.tests[-1].builder_diag')
                let a:total_result.tests[-1].builder_diag = ''
            endif

            let a:total_result.tests[-1].builder_diag .= ' ' . strpart(result.comment, 3)

            return result " do not set a:total_result.last_type
        endif

    elseif len(m_bailout)
        let [ reason ] = m_bailout[1:1]

        let result.type = 'bailout'
        let result.reason = reason

        let a:total_result.bailout = 1

    elseif len(m_error)
        let [ message, file, line ] = m_error[1:3]

        let result.type = 'other_error'
        let error = { 'message': message, 'file': file, 'line': line }
        call add(a:total_result.other_errors, error)

    else
        let result.type = 'unknown'

    endif

    if !exists('a:total_result.last_type')
        let a:total_result.last_type = ''
    endif

    let a:total_result.last_type = result.type

    return result
endfunction

function! tap#run (command, file)
    execute 'normal!' (line('.') == 1 ? 'C' : 'o') . a:file
                \ repeat('.', (len(a:file) / 32 + 1) * 32 + 3 - len(a:file)) ''

    redraw
    let incremental = exists('g:tap#use_vimproc') && g:tap#use_vimproc
    let b:tap_running = 1

    if incremental
        let result = tap#init_parse_result()
        let p = vimproc#popen2(a:command)
        let buf = ''
        while !p.stdout.eof
            let buf .= p.stdout.read()
            let [lines, buf] = matchlist(buf, '^\(\_.\{-}\)\(\%(\n\@!.\)*\)$')[1:2]
            for line in split(lines, '\n')
                put =line
                redraw
                call tap#parse_line(line, result)
            endfor
        endwhile

        while 1
            let [s, exit_code] = p.waitpid()
            if s == 'exit'
                break
            endif
        endwhile
    else
        let result = tap#parse(system(a:command))
        let exit_code = v:shell_error
    endif

    let failed = exit_code != 0 || get(result, 'failed', 0)

    if !incremental
        put =result.raw
    endif

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

    for e in result.other_errors
        call setqflist([ { 'filename': e.file, 'lnum': e.line, 'text': printf('(when testing %s) %s', a:file, e.message) } ], 'a')
    endfor

    let b:tap_running = 0

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
    let arg = a:0 ? a:1 : expand('%') =~ '\.t$' ? expand('%') : 't'
    let files = split(glob(isdirectory(arg) ? arg . '/**/*.t' : arg), "\0")

    let command = 'perl -Ilib' " TODO option
    if exists('b:tap_run_command')
        let command = b:tap_run_command
    end

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
        setlocal buftype=nofile filetype=tap-result
        setlocal foldmethod=syntax foldtext=b:tap_running?getline(v:foldend-1):getline(v:foldstart).(v:foldend-1<=v:foldstart?'\ \ \ \ \ ':getline(v:foldend-1))
        let b:tap_running = 0
        let b:tap_test_target = files
        execute 'file' escape(bufname, ' *%\')
        " autocmd BufUnload <buffer> bwipeout
        call tap#setup_highlights()
    endif

    call setqflist([])
    normal! zM

    for file in files
        let line = join(readfile(file, '', 1))
        let opt_taint = matchstr(line, '^#!.*\<perl.*\s\zs-[Tt]\+')

        let result = tap#run(command . ' ' . (len(opt_taint) ? ' ' . opt_taint : '') . file, file)
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

if exists('g:tap#develop') && g:tap#develop
    augroup tap#develop
        autocmd!
        autocmd CursorHold *
                    \ silent! delfunction tap#prove
                    \ | augroup tap#develop
                    \ |     execute 'autocmd!'
                    \ | augroup END
        autocmd CursorHoldI *
                    \ silent! delfunction tap#prove
                    \ | augroup tap#develop
                    \ |     execute 'autocmd!'
                    \ | augroup END
    augroup END
endif

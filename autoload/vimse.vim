" Main file of VimSE, a general purpose 'runtime library' for Vim.
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 15.12.2021
" (c) Marcel Simader 2021

" Conservative estimate about how long a line can be for these functions to work.
let g:VIMSE_EOL = 99999999

" A primitve verison of Vim's builint 'input()' function, but with a callback for each
" input key. This function asks the user for a prompt string and then captures characters
" that are typed. Backspaces are supported, but almost nothing else. An input is
" terminated by Escape or Enter. When a character is typed, 'OnChange' is called.
" Completion mode is largely supported, including custom completion functions.
"
" Arguments:
"   [prompt,] the prompt that is used directly, probably add a space at the end, defaults
"       to an empty string
"   [default,] the default string at the start of the input procedure
"   [complete,] the Vim specified completion argument, see ':h :command-complete'
"   [OnChange,] a function taking two parameters that is called when a character is input,
"       of form (complete_string, new_char) -> ..., defaults to 'v:none'
" Returns:
"   the final input as string
function vimse#Input(prompt = '', default = '', complete = v:none, Onchange = v:none)
    let ignore = [
                \ "\<CursorHold>",
                \ "\<LeftMouse>", "\<LeftDrag>", "\<LeftRelease>",
                \ "\<MiddleMouse>", "\<MiddleDrag>", "\<MiddleRelease>",
                \ "\<RightMouse>", "\<RightDrag>", "\<RightRelease>",
                \ "\<2-LeftMouse>", "\<2-MiddleMouse>", "\<2-RightMouse>",
                \ "\<3-LeftMouse>", "\<3-MiddleMouse>", "\<3-RightMouse>",
                \ "\<C-LeftMouse>", "\<C-MiddleMouse>", "\<C-RightMouse>",
                \ "\<S-LeftMouse>", "\<S-MiddleMouse>", "\<S-RightMouse>",
                \ "\<M-LeftMouse>", "\<M-MiddleMouse>", "\<M-RightMouse>",
                \ ]
    " chars is the current state of the output string
    let chars = a:default
    " stub is the original text at start of completion mode
    " list is the options that can be flipped through where index 0 is always the stub
    " idx is the current index in the list
    let complete_stub = v:none
    let complete_list = []
    let complete_idx  = 0
    call inputsave()
    echon a:prompt.chars
    " accumulate characters
    while 1
        let c = getcharstr()
        " skip cursorhold and other stuff, see ':h getchar()'
        while index(ignore, c) != -1
            let c = getcharstr()
        endwhile
        " end loop on ESC or CR
        if c == "\<ESC>" || c == "\<CR>"
            break
        endif
        " handle completion
        if !((a:complete is v:none) || empty(a:complete))
                    \ && (c == "\<Tab>" || c == "\<S-Tab>")
            " get current completions if we were not in completion mode
            if complete_stub is v:none
                let complete_stub = chars
                try
                    let complete_list = s:getcompletion_custom(
                                \ complete_stub, a:complete,
                                \ chars, chars, len(chars))
                catch 'E475'
                    " the function might not cooperate so catch that and just end
                    " the loop instead of trapping the user in an empty screen
                    echohl ErrorMsg
                    echomsg 'VimSE: Invalid completion argument'
                    echomsg '-- '.v:exception
                    echohl None
                    break
                endtry
                " complete_list is of form [stub, ...options] so wrapping is easier
                call insert(complete_list, complete_stub, 0)
                let complete_idx  = 0
            endif
            let complete_idx = (complete_idx + ((c == "\<S-Tab>") ? -1 : 1))
                        \ % len(complete_list)
            let chars = complete_list[complete_idx]
        else
            " we are in complete mode but it was not tab so use the current prompt
            if !(complete_stub is v:none)
                let complete_stub = v:none
                let complete_list = []
                let complete_idx  = 0
            endif
            " we have our new character now
            " if backspace, remove one character, otherwise add to chars
            let chars = (c == "\<Backspace>") ? chars[:-2] : chars.c
        endif
        if !(a:Onchange is v:none) | call a:Onchange(chars, c) | endif
        " print prompt and so far entered characters
        redraw | echon a:prompt.chars
    endwhile
    redraw
    call inputrestore()
    return chars
endfunction

" Same as 'getcompletion()' but with support for 'custom,{func}' and 'customlist,{func}'
" types. This will throw error E475 if a wrong 'type' is passed.
function s:getcompletion_custom(pat, type, ArgLead = '', CmdLine = '', CursorPos = 0)
    let custom_compl = matchlist(a:type, 'custom\%(list\)\=,\(.*\)')
    let funcname = trim(get(custom_compl, 1, ''))
    return empty(funcname)
                \ ? getcompletion(a:pat, a:type)
                \ : function(funcname)(a:ArgLead, a:CmdLine, a:CursorPos)
endfunction

" First, executes 'vimse#SmartInsert' with the given arguments, and then
" 'vimse#TemplateString' on the inserted text.
" See:
"   vimse#SmartInsert
"   vimse#TemplateString
function vimse#Template(lnum, lines, numargs,
            \ finalcursoroffset = [],
            \ argnames = [], argdefaults = [], argcomplete = [],
            \ indent = -1, noundo = 0)
    " save undo state
    let undostate = undotree()['seq_cur']

    call vimse#SmartInsert(a:lnum, a:lines, a:indent)
    let ret = vimse#TemplateString(a:lnum, a:lnum + len(a:lines), 0, g:VIMSE_EOL,
                \ a:numargs, a:argnames, a:argdefaults, a:argcomplete)

    if ret == 0 && !a:noundo
        " set to 'undostate' for all other changes
        " and undo once for this method
        silent execute 'undo '.undostate
        silent undo
    else
        if len(a:finalcursoroffset) >= 2
            call cursor([a:finalcursoroffset[0] + a:lnum] + a:finalcursoroffset[1:])
        endif
    endif
endfunction

" Same as 'vimse#Template' but for inline, surround-based templates.
" See:
"   vimse#Template
function vimse#InlineTemplate(lstart, lend, cstart, cend, before, after, numargs,
            \ finalcursoroffset = [],
            \ argnames = [], argdefaults = [], argcomplete = [],
            \ middleindent = -1, noundo = 0)
    " save undo state
    let undostate = undotree()['seq_cur']

    call vimse#SmartSurround(a:lstart, a:lend, a:cstart, a:cend, a:before, a:after,
                \ a:middleindent)
    let ret = vimse#TemplateString(a:lstart, a:lend, a:cstart, a:cend, a:numargs,
                \ a:argnames, a:argdefaults, a:argcomplete)

    if ret == 0 && !a:noundo
        " set to 'undostate' for all other changes
        " and undo once for this method
        silent execute 'undo '.undostate
        silent undo
    else
        if len(a:finalcursoroffset) >= 2
            call cursor([a:finalcursoroffset[0] + a:lstart,
                      \  a:finalcursoroffset[1] + a:cstart] + a:finalcursoroffset[2:])
        endif
    endif
endfunction

" Takes a section of text as input and replaces specific patterns with the user's input.
"
" This is easiest explained with an example case, here we replace the language and the
" code of a Markdown code block with user input. The template text specified by the
" template variable format '#n' looks like this:
"
" 1 | ```#1
" 2 | #2
" 3 | ```
"
" The call would look like this: 'vimse#TemplateString(1, 3, 0, g:VIMSE_EOL, 2)'. One may
" also name the arguments, provide defaults, or provide a completion argument (see
" ':h input()' for details).
"
" It is possible to modify the user input before putting it into the template by writing
" the argument not as '#n', but as '#/pat/sub/n'. For instance if we wanted to make sure
" the code was indented correctly (with two spaces), we could use the following template
" variable:
"
" 1 | ```#1
" 2 |   #/\\n/\n  /2
" 3 | ```
"
" To include a literal '#', simply use '\#'. For instance, to include '#1' in the
" output, write '\#1'.
"
" Arguments:
"   lstart, the line to start on
"   lend, the line to end on
"   cstart, the column to start on
"   cend, the column to end on
"   numargs, the number of template variables to search for
"   [argnames,] the names displayed for each argument input prompt as list
"   [argdefaults,] the default text displayed for each input prompt as list
"   [argcomplete,] the completion argument for each input prompt as list
" Returns:
"   the number '1' if the template was filled out, or '0' if the user aborted it or a
"   problem ocurred during the operation
function vimse#TemplateString(lstart, lend, cstart, cend, numargs,
            \ argnames = [], argdefaults = [], argcomplete = [])
    " status indicates whether the function returns with 1 or 0, as specified by the
    " docstring above
    let status = 1
    let lines = getline(a:lstart, a:lend)
    let haspopup = has('popupwin')
    let win = win_getid()

    " put cursor on first col
    let oldpos = getpos('.')
    call cursor(a:lstart, a:cstart)

    " iterates over indices and makes regular expression pattern for the template
    " variables
    for argidx in range(a:numargs)
        let pat      = '\\\@1<!#\(/.\{-1,}/.\{-}/\)\='.string(argidx + 1)
        let name     = get(a:argnames   , argidx, 'Text: ')
        let default  = get(a:argdefaults, argidx, '')
        let complete = get(a:argcomplete, argidx, '')
        " get positions of replace items
        let positions = map(vimse#AllMatchStrPos(lines, pat),
                    \ {_, val -> [
                    \     lines[val[1]],
                    \     val[0],
                    \     a:lstart + val[1],
                    \     val[2] + 1,
                    \     val[3] - val[2],
                    \ ]})
        let match_positions = mapnew(positions, {_, val -> [val[2], val[3], val[4]]})
        " setup hashGenDict which is entries of position hashes containing dictionairies
        " with the key 'lnum', 'line', 'pat', and 'Generate' (and 'popup')
        let hashGenDict = {}
        for [line, match, lnum, column, length] in positions
            let hashGenDict[s:posHash(lnum, column)] = {
                        \ 'lnum': lnum,
                        \ 'column': column,
                        \ 'lidx': lnum - a:lstart,
                        \ 'match': match,
                        \ 'Generate': {lidx, match, text ->
                        \     s:templateStringVariable(lines[lidx], text, match)},
                        \ }
        endfor
        " highlight area and redraw
        let match_id = (rand() % 8192) + 1
        call matchaddpos('Search', match_positions, g:VIMSE_EOL, match_id) | redraw
        " if possible, open a popup cause why not
        if haspopup
            for [hash, genDict] in items(hashGenDict)
                let posDict  = screenpos(win, genDict['lnum'], 1)
                let wincol   = get(get(getwininfo(win), 0, {}), 'wincol', 1)
                let width    = winwidth(win) - (posDict['col'] - wincol)
                " make 'popup' entry in hashGenDcit
                let popup_id = popup_create(
                            \ genDict['Generate'](
                            \     genDict['lidx'], genDict['match'], default
                            \ ),
                            \ {
                            \     'line'      : posDict['row'],
                            \     'col'       : posDict['col'],
                            \     'minwidth'  : width,
                            \     'maxwidth'  : width,
                            \     'pos'       : 'topleft',
                            \     'close'     : 'click',
                            \     'cursorline': 1,
                            \ })
                let genDict['popup'] = popup_id
            endfor
            function! UpdatePopups(text) closure
                for [hash, genDict] in items(hashGenDict)
                    call popup_settext(genDict['popup'],
                                \ genDict['Generate'](
                                \     genDict['lidx'], genDict['match'], a:text,
                                \ ))
                endfor
            endfunction
            " important! otherwise this will just not show up
            redraw
        endif
        " ask for input without or with completion options
        let text = vimse#Input(name, default, empty(complete) ? v:none : complete,
                    \ {str, _ -> haspopup ? UpdatePopups(str) : 0})
        " clear popups and highlight
        if haspopup
            for [hash, genDict] in items(hashGenDict)
                call popup_close(genDict['popup'])
            endfor
        endif
        call matchdelete(match_id)
        redraw
        " check for abort
        if empty(text)
            let status = 0
            break
        endif
        " we need to sort these items in order of lines and columns, so that when we
        " instert multiple lines later references can be updated in time
        let items = sort(sort(items(hashGenDict),
                    \ {a, b -> a[1]['column'] - b[1]['column']}),
                    \ {a, b -> a[1]['lnum']   - b[1]['lnum']})
        for [hash, genDict] in items
            let lidx = genDict['lidx']
            let newlines = genDict['Generate'](lidx, genDict['match'], text)
            " actually replace conents now
            undojoin | call vimse#SmartInsert(genDict['lnum'], newlines)
            " update lines list and all references in case we added lines
            let lines = slice(lines, 0, lidx) + newlines + slice(lines, lidx + 1)
            let linediff = len(newlines) - 1
            if linediff > 0
                for [nhash, ngenDict] in items
                    if nhash != hash && ngenDict['lnum'] >= genDict['lnum']
                        " this comes after the more than 1 lines we inserted
                        let ngenDict['lnum'] += linediff
                        let ngenDict['lidx'] += linediff
                    endif
                endfor
            endif
        endfor
    endfor

    " restore cursor position
    call setpos('.', oldpos)
    return status
endfunction

" Computes a hash of a line numebr and a column.
" Arguments:
"   lnum, the line number
"   column, the column
" Returns:
"   a string hash
function s:posHash(lnum, column)
    let s = string([a:lnum, a:column])
    return exists('*sha256') ? sha256(s) : s
endfunction

" Takes in a replacement variable pattern, and a match and returns the replaced lines as
" single string.
" Arguments:
"   line, the line to substitute inside
"   text, the text to replace the match by
"   match, a match of the replacement variable pattern
" Returns:
"   a list of strings with the interpreted variable, or an empty list if an error occurred
function s:templateStringVariable(line, text, match)
    " analyze the template string further to determine what to do
    let syndict = s:templateStringSyntax(a:match)
    if syndict['case'] == 1
        " case of simple substitution
        let new = a:text
    elseif syndict['case'] == 2
        " case of a regular expression substitution of the input
        let new = substitute(a:text, syndict['pat'], syndict['sub'], 'g')
    else
        echohl ErrorMsg
        echomsg 'Invalid replacement string syntax "'.a:match.'"'
        echohl None
        return []
    endif
    return split(substitute(a:line, syndict['regex'], new, 'g'), '\n')
endfunction

" internal function to handle the replacement syntax
" Arguments:
"   str, the template string to analyze
" Returns:
"   a dictionary with the following contents based on the template case:
"     - 'case: 1', a simple digit template like '#1', contains this number as 'num'
"     - 'case: 2', case with a digit and a regular expression substitution like '#/a/b/1,
"         contains the number as 'num', and the regular expression as 'pat' and 'sub'
"   Both cases include the 'regex' key which contains the regular expression that matched
"   the template variable.
function s:templateStringSyntax(str)
    " digit case
    let pat = '#\(\d\+\)'
    let match = matchlist(a:str, pat)
    if !empty(match)
        return #{case: 1, num: str2nr(match[1]), regex: pat}
    endif
    " sub case
    let pat = '#/\(.\{-1,}\)/\(.\{-}\)/\(\d\+\)'
    let match = matchlist(a:str, pat)
    if !empty(match)
        return #{case: 2, pat: match[1], sub: match[2], num: str2nr(match[3]), regex: pat}
    endif
    " def case
    return #{case: 0}
endfunction

" Returns all matches of 'pat' in the string 'expr' as list of strings.
" See 'vimse#AllMatchStrPos' for more information on the arguments.
function vimse#AllMatchStr(expr, pat, count = -1)
    return map(vimse#AllMatchStrPos(a:expr, a:pat, a:count), 'get(v:val, 0, "")')
endfunction

" Returns all positions of  matches of 'pat' in the string 'expr' as list of lists.
" Behaves like 'matchstrpos()'.
" Arguments:
"   expr, the expression to match against
"   pat, the pattern to look for
"   [count,] defaults to -1 for 'as many as possible', maximum number
"       of matches to look for
function vimse#AllMatchStrPos(expr, pat, count = -1)
    let [listmode, res, currline, curridx] = [type(a:expr) == v:t_list, [], 0, 0]
    " wrap in list
    let str = listmode ? copy(a:expr) : [a:expr]
    " while list not empty
    while !empty(str) && (a:count < 0 || len(res) < a:count)
        let [match, line, idx, end] = matchstrpos(str, a:pat)
        " no match
        if empty(match) | break | endif
        " shorten str
        let str[line] = str[line][idx + 1:]
        let str = str[line:]
        " update global indices
        if line > 0
            let currline += line
            let curridx = idx + 1
        else
            let curridx += idx + 1
        endif
        " add to results
        let tmpres =  [curridx - 1, curridx - 1 + (end - idx)]
        let res += [[match] + (listmode ? [currline] : []) + tmpres]
    endwhile
    return res
endfunction

" Returns the indent of argument 'str'. It takes into account
" spaces and tabs, where tabs are counted by the value returned
" by the 'shiftwidth()' function.
function vimse#StrIndent(str)
    " remove spaces from beginning and count to get indent
    let [str, indent] = [a:str, 0]
    while !empty(str) && (str[0] == ' ' || str[0] == "\t")
        let indent += (str[0] == ' ') ? (1) : (shiftwidth())
        let str = str[1:]
    endwhile
    return indent
endfunction

" Indents the lines in argument 'lines' from index start to end.
" NOTE: `start` and `end` are NOT line numbers! They are indices.
" Examples:
" 1.)
" | ABC 123                    |     ABC 123
" |     ABC 123       --->     |         ABC 123
" |      TTT        indent=4   |          TTT
" | ABC                        |     ABC
" 2.)
" |      ABC 123               |    ABC 123
" |   ABC 123         --->     | ABC 123
" |   TTT           indent=0   | TTT
" |    ABC                     |  ABC
" Arguments:
"   lines, a list of lines
"   indent, the number of spaces to indent, when set to any value smaller than 0, this
"       function will return the original list
"   [start,] defaults to '0', the line to start on
"   [end,] defaults to 'len(lines) - 1', the line to end on
" Returns:
"   The indented lines as new list.
function vimse#IndentLines(lines, indent, start = 0, end = len(a:lines) - 1)
    let lines = copy(a:lines)
    " early abort
    if a:indent < 0 | return lines | endif

    let [start, end] = [a:start, a:end]
    if end < start | let [start, end] = [end, start] | endif

    " get smallest indent in lines
    let indents = mapnew(lines[start:end], 'vimse#StrIndent(v:val)')
    let minindent = min(indents)
    " actual indenting by adding an offset to all (trimmed) strings
    " that makes the least indented line level with a:indent
    for i in range(start, end)
        let indentstr = repeat(' ', indents[i - start] + a:indent - minindent)
        " trim only at beginning of string
        let lines[i] = indentstr.trim(lines[i], " \t", 1)
    endfor
    return lines
endfunction

" Inserts the lines in argument 'lines' with indent of 'indent'
" (see 'vimse#IndentLines') at position 'lnum'. Line 'lnum'
" is overwritten, and the rest of the lines are inserted after it.
function vimse#SmartInsert(lnum, lines, indent = -1)
    if empty(a:lines) | return | endif
    let lnum = s:lnum(a:lnum)
    let lines = vimse#IndentLines(a:lines, a:indent)

    " set first line
    call setline(lnum, get(lines, 0, ''))
    " insert other lines
    for i in range(1, len(lines) - 1)
        call append(lnum + i - 1, get(lines, i, ''))
    endfor
endfunction

" Surrounds the lines given by 'lstart', 'lend', with the column
" offsets given by 'cstart', 'cend' with the text 'textbefore' and
" 'textafter'. When 'middleindent' is set to a non-negative value,
" the surrounded lines are indented by that number (see
" 'vimse#IndentLines').
" Arguments:
"   lstart, the start line in the current buffer
"   lend, the end line in the current buffer
"   cstart, the start column in the current buffer
"   cend, the end column in the current buffer,
"         `-1` means to the end of the line
"   textbefore, the text to appear before '[lstart, cstart]'
"   textafter, the text to appear after '[lend, cend]'
"   [middleindent,] when non-negative, sets the indent of lines
"       between 'lstart' and 'lend', excluding the added text
function vimse#SmartSurround(lstart, lend, cstart, cend,
            \ textbefore, textafter, middleindent = -1)
    let [lstart, lend] = [s:lnum(a:lstart), s:lnum(a:lend)]
    let [cstart, cend] = [a:cstart, a:cend]
    if cend == -1 | let cend = g:VIMSE_EOL | endif
    if lstart > lend | let [lstart, lend] = [lend, lstart] | endif
    if cstart > cend | let [cstart, cend] = [cend, cstart] | endif

    let cstart_m1       = max([cstart - 1, 0])
    let cend_m1         = max([cend - 1, 0])
    let cend_mcstart_m1 = max([cend - cstart - 1, 0])

    let startindent = indent(a:lstart)

    " construct lines
    let lines = []
    if lend - lstart == 0
        let middle = [getline(lstart)]
        " ~~~~~~~~~~
        " (L) [ ]
        let lines = [strpart(middle[0], 0, cstart_m1)
                    \ .get(a:textbefore, 0, '')]
        " [ ] append
        let lines += a:textbefore[1:]
        " [ ] (I) [ ] concat
        let lines[-1] .= strpart(middle[0], cstart_m1, cend - cstart)
                    \ .get(a:textafter, 0, '')
        " [ ] append
        let lines += a:textafter[1:]
        " [ ] (R) concat
        let lines[-1] .= strpart(middle[0], cend_m1)
    else
        let middle = getline(lstart, lend)
        " ~~~~~~~~~~
        " (LL) [ ]
        let lines = [strpart(middle[0], 0, cstart_m1)
                    \ .get(a:textbefore, 0, '')]
        " [ ] append
        let lines += a:textbefore[1:]
        " [ ] (LR) concat
        let lines[-1] .= strpart(middle[0], cstart_m1)
        "     ((I)) append
        let lines += middle[1:-2]
        "     (RL) [ ] concat
        let lines += [strpart(middle[-1], 0, cend_m1)]
        let lines[-1] .= get(a:textafter, 0, '')
        " [ ] append
        let lines += a:textafter[1:]
        " [ ] (RR) concat
        let lines[-1] .= strpart(middle[-1], cend_m1)
    endif

    " indent
    if a:middleindent >= 0
        let indentstart = len(a:textbefore) - 1
        let indentend   = len(lines) - (len(a:textafter) - 1) - 1
        if (indentstart >= 0) && (indentend < len(lines)) && (indentend >= indentstart)
            let lines = vimse#IndentLines(lines, a:middleindent, indentstart, indentend)
        endif
    endif

    " delete lines so we don't copy the middle ones
    call deletebufline(bufname(), lstart + 1, lend)
    " set and return final pos
    call vimse#SmartInsert(lstart, lines, startindent)
endfunction

" Make sure line numbers that are 0 get normalized to 1. Otherwise leave it alone.
function s:lnum(lnum)
    return (a:lnum == 0) ? 1 : a:lnum
endfunction


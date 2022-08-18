" Main file of VimSE, a general purpose 'runtime library' for Vim.
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 15.12.2021
" (c) Marcel Simader 2021

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
" The call would look like this: 'vimse#TemplateString(1, 3, 0, 999, 2)'. One may also
" name the arguments, provide defaults, or provide a completion argument (see ':h input()'
" for details).
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
    " argument errors
    if a:numargs < 1 | return 1 | endif
    " set up variables
    let status = 1
    let id = 42
    let lines = getline(a:lstart, a:lend)
    " put cursor on first col
    let oldpos = getpos('.')
    call cursor(a:lstart, a:cstart)
    " for all arguments
    for argidx in range(a:numargs)
        let pat = '#\(/.\{-1,}/.\{-}/\)\='.string(argidx + 1)
        " get positions of replace items and highlight
        let positions = map(vimse#AllMatchStrPos(lines, pat),
                    \ {_, val -> [a:lstart + val[1], val[2] + 1, val[3] - val[2]]})
        call matchaddpos('Search', positions, 999, id) | redraw
        " if possible, open a popup cause why not
        if has('popupwin')
            let popupwin_id = popup_atcursor(
                        \ 'Variable '.string(argidx + 1).' of '.string(a:numargs),
                        \ #{border: []})
            " IMPORTANT! otherwise this will just not show up
            redraw
        endif
        " ask for input without or with completion options
        if empty(get(a:argcomplete, argidx, ''))
            let text = input(get(a:argnames, argidx, 'Text: '),
                        \ get(a:argdefaults, argidx, ''))
        else
            let text = input(get(a:argnames, argidx, 'Text: '),
                        \ get(a:argdefaults, argidx, ''),
                        \ get(a:argcomplete, argidx, ''))
        endif
        if has('popupwin') | call popup_close(popupwin_id) | endif
        call matchdelete(id)
        " check for abort
        if empty(text) | let status = 0 | break | endif
        for [lnum, column, length] in positions
            let line = getline(lnum)
            let match = slice(line, column - 1, column + length)
            " analyze the template string further to determine what to do
            let syndict = s:TemplateStringSyntax(match)
            if syndict['case'] == 1
                " case of simple substitution
                let newtext = text
            elseif syndict['case'] == 2
                " case of a regular expression substitution of the input
                let newtext = substitute(text, syndict['pat'], syndict['sub'], 'g')
            else
                echohl ErrorMsg
                echo 'Invalid replacement string syntax "'.match.'"'
                echohl None
            endif
            let newlines = split(substitute(line, pat, newtext, ''), '\n')
            call vimse#SmartInsert(lnum, newlines)
        endfor
    endfor
    " restore cursor
    call setpos('.', oldpos)
    return status
endfunction

" internal function to handle the replacement syntax
" Arguments:
"   str, the template string to analyze
" Returns:
"   a dictionary with the following contents based on the template case:
"     - 'case: 1', a simple digit template like '#1', contains this number as 'num'
"     - 'case: 2', case with a digit and a regular expression substitution like '#/a/b/1,
"         contains the number as 'num', and the regular expression as 'pat' and 'sub'
function s:TemplateStringSyntax(str)
    " digit case
    let match = matchlist(a:str, '#\(\d\+\)')
    if !empty(match)
        return #{case: 1, num: str2nr(match[1])}
    endif
    " sub case
    let match = matchlist(a:str, '#/\(.\{-1,}\)/\(.\{-}\)/\(\d\+\)')
    if !empty(match)
        return #{case: 2, pat: match[1], sub: match[2], num: str2nr(match[3])}
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
    let str = listmode ? a:expr : [a:expr]
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
    " early abort
    if a:end < a:start || a:indent < 0
        return a:lines
    endif
    " get smallest indent in lines
    let minindent = min(map(a:lines[a:start:a:end], 'vimse#StrIndent(v:val)'))
    " actual indenting by adding an offset to all (trimmed) strings
    " that makes the least indented line level with a:indent
    for i in range(a:start, a:end)
        let indentstr = repeat(' ', vimse#StrIndent(a:lines[i]) + (a:indent - minindent))
        let a:lines[i] = indentstr.trim(a:lines[i])
    endfor
    return a:lines
endfunction

" Inserts the lines in argument 'lines' with indent of 'indent'
" (see 'vimse#IndentLines') at position 'lnum'. Line 'lnum'
" is overwritten, and the rest of the lines are inserted after it.
" Returns:
"   The end position of the cursor after the insert.
function vimse#SmartInsert(lnum, lines, indent = -1)
    call vimse#IndentLines(a:lines, a:indent)
    " set first line
    call setline(a:lnum, get(a:lines, 0, ''))
    " insert other lines
    for i in range(1, len(a:lines) - 1)
        call append(a:lnum + i - 1, get(a:lines, i, ''))
    endfor
    return [a:lnum + len(a:lines), strlen(get(a:lines, -1, '')) + 1]
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
"   cend, the end column in the current buffer
"   textbefore, the text to appear before '[lstart, cstart]'
"   textafter, the text to appear after '[lend, cend]'
"   [middleindent,] when non-negative, sets the indent of lines
"       between 'lstart' and 'lend'
" Returns:
"   The end position of the cursor after the insert.
function vimse#SmartSurround(lstart, lend, cstart, cend,
            \ textbefore, textafter, middleindent = -1)
    let startindent = indent(a:lstart)
    " construct lines
    if a:lend - a:lstart <= 0
        let middle = [getline(a:lstart)]
        " ~~~~~~~~~~
        " (L) [ ]
        let lines = [strpart(middle[0], 0, a:cstart - 1)
                    \ .get(a:textbefore, 0, '')]
        " [ ] append
        let lines += a:textbefore[1:]
        " [ ] (I) [ ] concat
        let lines[-1] .= strpart(middle[0], a:cstart - 1, a:cend - a:cstart)
                    \ .get(a:textafter, 0, '')
        " [ ] append
        let lines += a:textafter[1:]
        " [ ] (R) concat
        let lines[-1] .= strpart(middle[0], a:cend - 1, 999999)
    else
        let middle = getline(a:lstart, a:lend)
        " ~~~~~~~~~~
        " (LL) [ ]
        let lines = [strpart(middle[0], 0, a:cstart - 1)
                    \ .get(a:textbefore, 0, '')]
        " [ ] append
        let lines += a:textbefore[1:]
        " [ ] (LR) concat
        let lines[-1] .= strpart(middle[0], a:cstart - 1, 999999)
        "     ((I)) append
        let lines += middle[1:-2]
        "     (RL) [ ] concat
        let lines += [strpart(middle[-1], 0, a:cend - 1)]
        let lines[-1] .= get(a:textafter, 0, '')
        " [ ] append
        let lines += a:textafter[1:]
        " [ ] (RR) concat
        let lines[-1] .= strpart(middle[-1], a:cend - 1, 999999)
    endif
    " indent
    if a:middleindent >= 0
        call vimse#IndentLines(lines, a:middleindent, 1, len(lines) - 2)
    endif
    " delete lines so we don't copy the middle ones
    call deletebufline(bufname(), a:lstart + 1, a:lend)
    " set and return final pos
    return vimse#SmartInsert(a:lstart, lines, startindent)
endfunction


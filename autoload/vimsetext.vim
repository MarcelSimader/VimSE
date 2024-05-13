" Text-specific utility functions for VimSE.
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 20.01.2024
" License: See 'LICENSE' shipped with this repository
" (c) Marcel Simader 2024

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Private Functions ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" Make sure line numbers that are 0 get normalized to 1. Otherwise leave it alone.
function s:lnum(lnum)
    return (a:lnum == 0) ? 1 : a:lnum
endfunction

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Public API ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" Performs the reversed function of |match()| (matches from the right to the left), but
" using character indices instead of byte indices.
"
" XXX: There is no easy way to reverse the pattern 'pat', so you need to specify it in
"      reverse. Yes, it sucks, I'm sorry. :(
"
" NOTE: 'start' is the starting point *counted* from the left, but *matching* is done
"       from the right at that point.
"       The return value is also counted from the left.
function vimsetext#RCharMatch(expr, pat, start = v:none, count = v:none)
    let expr_len = strcharlen(a:expr)
    let rev_expr = reverse(copy(a:expr))
    let rev_start = (a:start is v:none) ? a:start : byteidx(a:expr, expr_len - a:start)
    call assert_true(rev_start != -1)
    let char_index = vimsetext#CharMatch(rev_expr, a:pat, rev_start, a:count)
    " -1 means no match, *not* an error with the 'charidx' call
    return (char_index == -1) ? char_index : (expr_len - char_index)
endfunction

" Performs the same function as |match()|, but using character indices instead of byte
" indices.
function vimsetext#CharMatch(expr, pat, start = v:none, count = v:none)
    let byte_index
                \ = (a:start is v:none && a:count is v:none)
                \   ? match(a:expr, a:pat)
                \ : (a:start isnot v:none && a:count is v:none)
                \   ? match(a:expr, a:pat, byteidx(a:expr, a:start))
                \ : (a:start isnot v:none && a:count isnot v:none)
                \   ? match(a:expr, a:pat, byteidx(a:expr, a:start), a:count)
                \ : v:none
    if byte_index is v:none
        " This is thrown when 'count' is given, but not 'start', which is just not
        " possible with builtin Vim functions
        throw "E475: Invalid argument: cannot give argument 'count' without 'start'"
    elseif byte_index == -1
        return byte_index
    else
        let char_index = charidx(a:expr, byte_index)
        call assert_true(char_index != -1)
        return char_index
    endif
endfunction

" Returns all matches of 'pat' in the string 'expr' as list of strings.
" See 'vimsetext#AllMatchStrPos' for more information on the arguments.
function vimsetext#AllMatchStr(expr, pat, count = -1)
    return map(vimsetext#AllMatchStrPos(a:expr, a:pat, a:count), 'get(v:val, 0, "")')
endfunction

" Returns all positions of  matches of 'pat' in the string 'expr' as list of lists.
" Behaves like 'matchstrpos()'.
" Arguments:
"   expr, the expression to match against
"   pat, the pattern to look for
"   [count,] defaults to -1 for 'as many as possible', maximum number
"       of matches to look for
function vimsetext#AllMatchStrPos(expr, pat, count = -1)
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
function vimsetext#StrIndent(str)
    " remove spaces from beginning and count to get indent
    let [str, indent] = [a:str, 0]
    while !empty(str) && (str[0] == ' ' || str[0] == "\t")
        let indent += (str[0] == ' ') ? 1 : shiftwidth()
        let str = strcharpart(str, 1)
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
function vimsetext#IndentLines(lines, indent, start = 0, end = len(a:lines) - 1)
    let lines = copy(a:lines)
    " early abort
    if a:indent < 0 | return lines | endif

    let [start, end] = [a:start, a:end]
    if end < start | let [start, end] = [end, start] | endif

    " get smallest indent in lines
    let indents = mapnew(lines[start:end], 'vimsetext#StrIndent(v:val)')
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
" (see 'vimsetext#IndentLines') at position 'lnum'. Line 'lnum'
" is overwritten, and the rest of the lines are inserted after it.
function vimsetext#SmartInsert(lnum, lines, indent = -1)
    if empty(a:lines) | return | endif
    let lnum = s:lnum(a:lnum)
    let lines = vimsetext#IndentLines(a:lines, a:indent)

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
" 'vimsetext#IndentLines').
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
function vimsetext#SmartSurround(lstart, lend, cstart, cend,
            \ textbefore, textafter, middleindent = -1)
    let [lstart, lend, flipped] = [s:lnum(a:lstart), s:lnum(a:lend), v:false]
    let [cstart, cend] = [a:cstart, a:cend]
    if cend == -1 | let cend = g:VIMSE_EOL | endif
    if lstart > lend | let [lstart, lend, flipped] = [lend, lstart, v:true] | endif
    if flipped | let [cstart, cend] = [cend, cstart] | endif

    let startindent = indent(a:lstart)
    let [cstart, cend] = [max([cstart - startindent, 0]), max([cend - startindent, 0])]
    let cstart_m1 = max([cstart - 1, 0])
    let cend_m1   = max([cend - 1, 0])

    " construct lines
    let lines = []
    if lend - lstart == 0
        let middle = [trim(getline(lstart), " \t", 1)]
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
        let middle = map(getline(lstart, lend), {_, v -> trim(v, " \t", 1)})
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
        let indentend   = len(lines) - len(a:textafter)
        if (indentstart >= 0) && (indentend < len(lines)) && (indentend >= indentstart)
            let lines = vimsetext#IndentLines(
                        \ lines, a:middleindent, indentstart, indentend)
        endif
    endif

    " delete lines so we don't copy the middle ones
    call deletebufline(bufname(), lstart + 1, lend)
    " set and return final pos
    call vimsetext#SmartInsert(lstart, lines, startindent)
endfunction

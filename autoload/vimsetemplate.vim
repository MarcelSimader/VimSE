" Templating functionality for the VimSE runtime.
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 28.01.2024
" License: See 'LICENSE' shipped with this repository
" (c) Marcel Simader 2024

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Private Fields ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

let s:TemplateCase_None = 0
let s:TemplateCase_Sub = 1
let s:TemplateCase_PatSub = 2

" Atoms
let s:TemplatePat_NoEscape = '\%(\%(^\|[^\\]\)\\\%(\\\\\)*\)\@16<!'
let s:TemplatePat_Leader = s:TemplatePat_NoEscape..'#'
let s:TemplatePat_Sep = s:TemplatePat_NoEscape..'/'
let s:TemplatePat_Num = '\(\d\+\)'
" Rules
let s:TemplatePat_Sub_NoNum = s:TemplatePat_Leader
let s:TemplatePat_Sub = s:TemplatePat_Sub_NoNum..s:TemplatePat_Num
" Here, we have to be careful to use the non-greedy operators between separators, since if
" we use a greedy operation, we might read over a separator erroneously
let s:TemplatePat_PatSub_NoNum = join(
            \ [s:TemplatePat_Leader, '\(.\{-1,}\)', '\(.\{-}\)', ''],
            \ s:TemplatePat_Sep)
let s:TemplatePat_PatSub = s:TemplatePat_PatSub_NoNum..s:TemplatePat_Num

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Private Functions ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" Handles the variable substitution syntax.
" Arguments:
"   str, the template string to analyze
" Returns:
"   When the operation succeeds, the result is a dictionary with a key named 'case'. Based
"   on this case number, the following dictionary variants are returned:
"
"   - case 'VIMSE_TemplateCase_None':
"       - 'case', always 0
"
"   - case 'VIMSE_TemplateCase_Sub':
"       - 'case', always 1
"       - 'num', the substituion number, as in #1, #2, ...
"       - 'regex': the regular expression used to match the variable substitution
"
"   - case 'VIMSE_TemplateCase_PatSub':
"       - 'case', always 2
"       - 'num', the substituion number, as in #1, #2, ...
"       - 'regex', the regular expression used to match the variable substitution
"       - 'pat', the pattern to match the user input on, as in #/pat/sub/1
"       - 'sub', the substitution pattern to apply on the user input, as in #/pat/sub/1
function s:templateStringVarSubMatch(str)
    " Pattern substituion case
    let pat = s:TemplatePat_PatSub
    let match = matchlist(a:str, pat)
    if !empty(match)
        return #{case: s:TemplateCase_PatSub, num: str2nr(match[3]), regex: pat,
                    \ pat: match[1], sub: match[2]}
    endif
    " Pattern case
    let pat = s:TemplatePat_Sub
    let match = matchlist(a:str, pat)
    if !empty(match)
        return #{case: s:TemplateCase_Sub, num: str2nr(match[1]), regex: pat}
    endif
    " Default (empty) case
    return #{case: s:TemplateCase_None}
endfunction

" Handles the creation of a variable substitution dictionary.
" Arguments:
"   lstart, the starting line of the templating region
"   match_str, the actual variable substitution match string
"   lnum, the variable substitution match line number
"   column, the variable substitution match column
"   len, the variable substitution match length
" Returns:
"   a dictionary with the data item 'len', and the methods 'lnum' (0 arguments), 'col' (0
"   arguments), 'line_idx' (0 arguments), and 'Apply' (takes in a list argument, and a
"   replacement text)
"
"   four protected fields, 'real_lnum', 'real_col', 'offset_lnum', and 'offset_col' are
"   used to offset 'lnum', and 'col', respectively, without modifying them directly
function s:templateStringVarSubMake(lstart, match_str, lnum, column, len)
    let obj = { 'len': a:len,
              \ 'real_lnum': a:lnum, 'real_col': a:column,
              \ 'offset_lnum': 0, 'offset_col': 0,
              \ }
    " Begin dict functions
    function obj.lnum()
        return self['real_lnum'] + self['offset_lnum']
    endfunction
    function obj.col()
        return self['real_col'] + self['offset_col']
    endfunction
    function obj.line_idx() closure
        return self['lnum']() - a:lstart
    endfunction
    function obj.Apply(line_list, text) closure
        " analyze the template string further to determine what to do
        let syndict = s:templateStringVarSubMatch(a:match_str)
        if syndict['case'] == s:TemplateCase_Sub
            " case of simple substitution
            let new_text = a:text
        elseif syndict['case'] == s:TemplateCase_PatSub
            " case of a regular expression (pattern) substitution of the input
            let new_text = substitute(a:text, syndict['pat'], syndict['sub'], 'g')
        else
            throw 'VimSE: Invalid replacement string syntax "'.a:match_str.'"'
        endif
        let match_after  = '\%>'..string(max([self['col']() - 1, 0]))..'v'
        let match_before = '\%<'..string(self['col']() + self['len'] + 1)..'v'
        return [ len(new_text) - self['len'],
               \ split(
               \     substitute(
               \         a:line_list[self['line_idx']()],
               \         match_after..syndict['regex']..match_before,
               \         new_text,
               \         '',
               \     ),
               \     '\n',
               \     v:true,
               \ ),
               \ ]
    endfunction
    " End dict functions, have a enjoy
    return obj
endfunction

" Takes in a variable substitution dict with the structure
"     { [lnum0]: { [col0]: [vsub0], [col1]: [vsub1], ... }, [lnum1]: ... },
" and iteratively applies the variable substitutions, so that the line numbers and columns
" are correct, even if multiple new lines are inserted.
" Arguments:
"   vsub_dict, the dictionary of dictionaries described above
"   lines, the lines selected for the template, will *NOT* be modified in-place
"   text, the user input to use for substitution
" Returns:
"   an array of two objects:
"       1.) a dictionary containing keys (value does not matter) of the line numbers that
"           were actually affected
"       2.) a list of strings containing the final, variable substituted lines
function s:templateStringVarSub(vsub_dict, lines, text)
    " Reset the offset fields
    for vsub_line in values(a:vsub_dict)
        for vsub in values(vsub_line)
            let vsub['offset_lnum'] = 0
            let vsub['offset_col'] = 0
        endfor
    endfor
    let result_lines = copy(a:lines)
    let changed_lnums = {}
    " NOTE: We can only sort by the keys, *NOT* use them directly (see offset)
    let sorted_vsub_lines = sort(items(a:vsub_dict), {a, b -> a[0] - b[0]})
    for [_, vsub_line] in sorted_vsub_lines
        let sorted_vsubs = sort(items(vsub_line), {a, b -> a[0] - b[0]})
        for [_, vsub] in sorted_vsubs
            let [lnum, col] = [vsub['lnum'](), vsub['col']()]
            " apply variable substitution, and update lines list
            let [replace_len, new_lines] = vsub['Apply'](result_lines, a:text)
            let lidx = vsub['line_idx']()
            let result_lines = slice(result_lines, 0, lidx)
                         \ + new_lines
                         \ + slice(result_lines, lidx + 1)
            let ldiff = len(new_lines) - 1
            call assert_true(ldiff >= 0)
            for changed_lnum in range(lidx, lidx + ldiff)
                let changed_lnums[changed_lnum] = v:true
            endfor
            " save the length of the last line that was *added* (like above)
            let last_line_len = len(new_lines[-1])
            " now, go through the objects coming after this column and line, and update
            " their 'offset_lnum' and 'offset_col' data items
            for other_vsub_line in values(a:vsub_dict)
                " we can skip any line coming before
                for other_vsub in values(other_vsub_line)
                    let [other_lnum, other_col]
                                \ = [other_vsub['lnum'](), other_vsub['col']()]
                    " we don't want to compare two identical entries
                    if (other_lnum == lnum) && (other_col == col) | continue | endif
                    if ldiff == 0
                        if (other_lnum == lnum) && (other_col > col)
                            " Before expansion:
                            " 1 | [ORIGINAL TEMPLATE] ... [OUR TEMPLATE]
                            "                       ↑
                            " ======================|====================================
                            " After expansion:      |
                            " 1 | TEMPLATE ACROSS SINGLE LINE ... [OUR TEMPLATE]
                            "                       \------/
                            "                      replace_len
                            let other_vsub['offset_col'] += replace_len
                        endif
                    else
                        " from here on out, we only care about cases where at least one
                        " line was *added* (i.e. 2 lines in total)
                        if other_lnum > lnum
                            "             Before expansion:
                            "             1 | [ORIGINAL TEMPLATE]
                            "             2 | ...
                            "             3 | [OUR TEMPLATE]
                            "
                            " ===========================================================
                            "             After expansion:
                            "             1 | TEMPLATE ...
                            "     ldiff / 2 | ... EXPANSION ...
                            "           \ 3 | ... ACROSS LINES
                            "             4 | ...
                            " new_lnum -> 5 | [OUR TEMPLATE]
                            let other_vsub['offset_lnum'] += ldiff
                        elseif (other_lnum == lnum) && (other_col > col)
                            " Before expansion:
                            " 1 | [ORIGINAL TEMPLATE] ........ [OUR TEMPLATE]
                            "                                  ↑
                            "                  real_col --->---+
                            "
                            " ===========================================================
                            " After expansion:
                            " 1 | TEMPLATE ...
                            " 2 | ... EXPANSION ...
                            " 3 | ... ACROSS LINES ........ [OUR TEMPLATE]
                            "     \                         ↑__our_len__/
                            "      \---------- last_line_len ----------/
                            "                               |
                            "             new_column --->---+
                            "          ^= real_col + offset_col
                            "
                            "       offset_col := real_col
                            "                  + (last_line_len - our_len + 1 - real_col)
                            "
                            "  ( The '+ 1' is for the column offset: We start at 1. )
                            let other_len = other_vsub['len']
                            let other_vsub['offset_lnum'] += ldiff
                            let other_vsub['offset_col']
                                        \ = (1 + last_line_len - other_len)
                                        \ - other_vsub['real_col']
                        endif
                    endif
                endfor
            endfor
        endfor
    endfor
    return [changed_lnums, result_lines]
endfunction

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Public API ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" Same as 'vimsetemplate#Template()' but for inline, surround-based templates.
" See:
"   vimsetemplate#Template()
function vimsetemplate#InlineTemplate(lstart, lend, cstart, cend, before, after, numargs,
            \ finalcursoroffset = [],
            \ argnames = [], argdefaults = [], argcomplete = [],
            \ middleindent = -1, skipundo = v:false)
    call vimsetext#SmartSurround(a:lstart, a:lend, a:cstart, a:cend,
                \ a:before, a:after,
                \ a:middleindent)
    let ret = vimsetemplate#TemplateString(win_getid(),
                \ a:lstart, a:lend, a:cstart, a:cend,
                \ a:numargs, a:argnames, a:argdefaults, a:argcomplete,
                \ a:skipundo, v:true)
    if (ret == 0) && !a:skipundo | silent undo | endif
    if len(a:finalcursoroffset) >= 2
        call cursor([a:finalcursoroffset[0] + a:lstart,
                  \  a:finalcursoroffset[1] + a:cstart] + a:finalcursoroffset[2:])
    endif
    return ret
endfunction

" First, executes 'vimsetext#SmartInsert()' with the given arguments, and then
" 'vimsetemplate#TemplateString()' on the inserted text.
" See:
"   vimsetext#SmartInsert()
"   vimsetemplate#TemplateString()
function vimsetemplate#Template(lnum, lines, numargs,
            \ finalcursoroffset = [],
            \ argnames = [], argdefaults = [], argcomplete = [],
            \ indent = -1, skipundo = v:false)
    call vimsetext#SmartInsert(a:lnum, a:lines, a:indent)
    let ret = vimsetemplate#TemplateString(win_getid(),
                \ a:lnum, a:lnum + len(a:lines) - 1,
                \ 0, g:VIMSE_EOL,
                \ a:numargs, a:argnames, a:argdefaults, a:argcomplete,
                \ a:skipundo, v:true)
    if (ret == 0) && !a:skipundo | silent undo | endif
    if len(a:finalcursoroffset) >= 2
        call cursor([a:finalcursoroffset[0] + a:lnum] + a:finalcursoroffset[1:])
    endif
    return ret
endfunction

" Takes a section of text as input and replaces specific patterns with the user's input.
"
" This is easiest explained with an example case, here we replace the language and the
" code of a Markdown code block with user input. The template text specified by the
" template variable format '#n' (called variable substitution) looks like this:
"
" 1 | ```#1
" 2 | #2
" 3 | ```
"
" The call would look like this: 'vimsetemplate#TemplateString(1, 3, 0, g:VIMSE_EOL, 2)'.
" One may also name the arguments, provide defaults, or provide a completion argument (see
" |vimseio#input()| for details).
"
" It is possible to modify the user input before putting it into the template by writing
" the argument not as '#n', but as '#/pat/sub/n' (called variable pattern substitution).
" For instance if we wanted to make sure the code was indented correctly (with two
" spaces), we could use the following template variable:
"
" 1 | ```#1
" 2 |   #/\\n/\n  /2
" 3 | ```
"
" To include a literal '#', simply use '\#'. For instance, to include '#1' in the output,
" write '\#1'. The same goes for '/' (as '\/') inside a variable pattern substitution.
"
" Arguments:
"   winid, the window ID
"   lstart, the line to start on
"   lend, the line to end on
"   cstart, the column to start on
"   cend, the column to end on, when -1 is given, until the end of the line
"   numargs, the number of template variables to search for
"   [argnames,] the names displayed for each argument input prompt as list
"   [argdefaults,] the default text displayed for each input prompt as list
"   [argcomplete,] the completion argument for each input prompt as list
"   [skipundo,] when this is set to true, aborting the template will not undo the changes
"       made so far, otherwise the undo is performed automatically
"   [joinundo,] when this is set to true, the undo block created by this function is
"       joined with the callee's (see |undo-blocks|)
" Returns:
"   the number '1' if the template was filled out, or '0' if the user aborted it, or a
"   problem occurred during the operation
function vimsetemplate#TemplateString(winid, lstart, lend, cstart, cend,
            \ numargs, argnames = [], argdefaults = [], argcomplete = [],
            \ skipundo = v:false, joinundo = v:false)
    let cend = (a:cend < 0) ? g:VIMSE_EOL : a:cend
    let bufnr = winbufnr(a:winid)
    " status indicates whether the function returns with 1 or 0, as specified by the
    " docstring above
    let status = 1
    " get lines selected by arguments
    let lines = getbufline(bufnr, a:lstart, a:lend)
    " save cursor position, and undo state
    let oldpos = getpos('.')
    let undostate = undotree(bufnr)['seq_cur']

    " put cursor on first col
    call cursor(a:lstart, a:cstart)

    " iterates over indices and makes regular expression pattern for the variable
    " substitution regular expressions
    let join = a:joinundo
    for argidx in range(a:numargs)
        let name     = get(a:argnames   , argidx, 'Text: ')
        let default  = get(a:argdefaults, argidx, '')
        let complete = get(a:argcomplete, argidx, '')
        " get positions of replace items
        " here, we also need to iterate over the possible cases of variable substitution
        let full_matches = []
        let position_matches = []
        for pat in [s:TemplatePat_Sub_NoNum, s:TemplatePat_PatSub_NoNum]
            " we need to add the number of the current variable to the end of the pattern
            let pat_and_num = pat..string(argidx + 1)
            let new_full_matches = filter(
                        \ map(vimsetext#AllMatchStrPos(lines, pat_and_num),
                        \     {_, val -> [
                        \         lines[val[1]],
                        \         val[0],
                        \         a:lstart + val[1],
                        \         val[2] + 1,
                        \         val[3] - val[2],
                        \     ]}),
                        \ {_, val -> (val[3] >= a:cstart) && ((val[3] + val[4]) <= cend)}
                        \ )
            let full_matches += new_full_matches
            let position_matches += map(new_full_matches, {_, val -> val[2:4]})
        endfor
        if (len(full_matches) < 1) || (len(position_matches) < 1)
            echohl WarningMsg
            echomsg 'VimSE: No matching template found for variable'
                        \ ..' substitution number "'..string(argidx + 1)
                        \ ..'". Skipping...'
            echohl None
            continue
        endif
        " set up a variable substituion dictionary like follows
        "
        "     { [lnum0]: { [col0]: [vsub0], [col1]: [vsub1], ... }, [lnum1]: ... }
        "
        " the outer dictionary contains line numbers, the inner column numbers
        " we use a dictionary of dictionaries for two reasons here: 1.) it helps avoid
        " duplicates by acting as a set, and 2.) we can index lines directly without
        " having to iterate over all lines
        "
        " NOTE: We can only sort by the keys, *NOT* use them directly (see offset)
        let vsub_dict = {}
        for [_, match_str, lnum, column, len] in full_matches
            if !has_key(vsub_dict, lnum) | let vsub_dict[lnum] = {} | endif
            let vsub_dict[lnum][column] = s:templateStringVarSubMake(
                        \     a:lstart, match_str, lnum, column, len,
                        \ )
        endfor
        " if possible, open a popup preview, cause why not!
        if has('popupwin')
            let curr_previews = {}
            " closure to close all previews
            function! ClosePreviews() closure
                for [lnum, preview] in items(curr_previews)
                    call preview['close']()
                    call remove(curr_previews, lnum)
                endfor
            endfunction
            " closure to update all previews
            function! UpdatePreviews(text) closure
                let [changed_lines, prev_lines]
                            \ = s:templateStringVarSub(vsub_dict, lines, a:text)
                " close previews that are left over
                for [lnum, preview] in items(curr_previews)
                    if has_key(changed_lines, lnum - a:lstart) | continue | endif
                    call preview['close']()
                    call remove(curr_previews, lnum)
                endfor
                " open new previews, or update existing ones
                for line_idx in keys(changed_lines)
                    let lnum = line_idx + a:lstart
                    let line = prev_lines[line_idx]
                    if has_key(curr_previews, lnum)
                        call curr_previews[lnum]['update'](line)
                    else
                        let curr_previews[lnum]
                                    \ = vimseprev#LinePreview(
                                    \    a:winid, lnum, v:false, v:false, line,
                                    \ )
                    endif
                endfor
            endfunction
        else
            function! ClosePreviews()
            endfunction
            function! UpdatePreviews(text)
            endfunction
        endif
        " highlight text involved in variable substitution and redraw, IDs must start at
        " 5, at least, see |matchadd()|
        let match_id = or(rand() % 8192, 5)
        call matchaddpos('Search', position_matches, 5, match_id)
        redraw

        " ask user for input, with or without completion options
        let text = vimseio#Input(
                    \     name,
                    \     default,
                    \     empty(complete) ? v:none : complete,
                    \     {str, _ -> UpdatePreviews(str)},
                    \ )

        if join | undojoin | endif
        let join = v:true
        " clear previews and highlight
        call matchdelete(match_id)
        call ClosePreviews()
        redraw
        " check for user abort
        if text is v:none
            let status = 0
            break
        endif
        " update text, if successful input
        let previous_len = len(lines)
        let [_, lines] = s:templateStringVarSub(vsub_dict, lines, text)
        call appendbufline(bufnr, a:lstart, repeat([''], len(lines) - previous_len - 1))
        call setbufline(bufnr, a:lstart, lines)
    endfor

    if (status == 0) && !a:skipundo
        " set to 'undostate' for all other changes and undo once for this method
        silent execute 'undo '.undostate
    endif
    " restore cursor position
    call setpos('.', oldpos)
    return status
endfunction

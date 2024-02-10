" Input/output functions for the VimSE runtime.
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 26.01.2024
" License: See 'LICENSE' shipped with this repository
" (c) Marcel Simader 2024

let g:VIMSE_ignore_keys = ["\<CursorHold>"]
" 'D-' is a MacOS-only modifier key (the Command key)
let s:modifiers = ['', 'C-', 'S-', 'M-', 'C-S-', 'C-M-', 'S-M-', 'C-S-M-']
              \ + (has('mac') ? ['D-', 'C-D-', 'S-D-', 'C-S-D-'] : [])
" Add a *crap ton* of mouse key codes... also the scroll wheel mouse key codes
for s:modifier in s:modifiers
    for s:count in ['', '2-', '3-', '4-']
        for s:mouse_key in ['Left', 'Middle', 'Right']
            for s:action in ['Mouse', 'Drag', 'Release']
                " We need to do this weird 'eval' trick to get the actual bytes
                " corresponding to the key code name
                let g:VIMSE_ignore_keys += [
                            \ eval('"\<'.s:modifier.s:count.s:mouse_key.s:action.'>"')
                            \ ]
            endfor
        endfor
    endfor
    for s:scroll_dir in ['Up', 'Down', 'Left', 'Right']
        let g:VIMSE_ignore_keys += [
                    \ eval('"\<'.s:modifier.'ScrollWheel'.s:scroll_dir.'>"')
                    \ ]
    endfor
endfor
unlet s:modifier s:modifiers s:count s:mouse_key s:action s:scroll_dir

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Private Functions ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" Same as 'getcompletion()' but with support for 'custom,{func}' and 'customlist,{func}'
" types. This will throw error E475 if a wrong 'type' is passed.
function s:getcompletion_custom(pat, type, ArgLead = '', CmdLine = '', CursorPos = 0)
    let custom_compl = matchlist(a:type, 'custom\%(list\)\=,\(.*\)')
    let funcname = trim(get(custom_compl, 1, ''))
    return empty(funcname)
                \ ? getcompletion(a:pat, a:type)
                \ : function(funcname)(a:ArgLead, a:CmdLine, a:CursorPos)
endfunction

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Public API ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
"   [complete,] the Vim specified completion argument, see |command-complete|
"   [OnChange,] a function taking 2 arguments that is called when a character is input,
"       of form (complete_string, new_char) -> number, when the return value is
"       1/v:true/... this function closes the prompt early, defaults to 'v:none'
"   [OnStart,] a function taking 0 arguments, which is called when this function finishes
"       initialization, of form () -> ..., defaults to 'v:none'
"   [OnEnd,] a function taking 1 argument, which is called when this function ends, of
"       form (text) -> ..., defaults to 'v:none'
" Returns:
"   the final input as string, or |v:none| if the input was aborted
function vimseio#Input(prompt = '', default = '', complete = v:none,
            \ Onchange = v:none, OnStart = v:none, OnEnd = v:none)
    " XXX: READ ME BEFORE WORKING ON THIS FUNCTION!
    "      Be careful with the byte index and character index distinction!

    " chars is the current state of the output string
    " cursor_idx is the location of the cursor in the input IN CHARACTERS
    let chars = a:default
    let cursor_idx = 0
    " complete_stub is the original text at start of completion mode
    " complete_list is the options that can be flipped through, index 0 is always stub
    " complete_idx is the current index in the list
    let complete_stub = v:none
    let complete_list = []
    let complete_idx  = 0

    call inputsave()
    echon a:prompt chars

    let first_loop = v:true
    while 1
        " skip cursorhold, mouse keys, scrolling, and other stuff, see ':h getchar()'
        if first_loop && (a:OnStart isnot v:none) | call a:OnStart() | endif
        let first_loop = v:false
        let c = getcharstr()
        while index(g:VIMSE_ignore_keys, c) != -1 | let c = getcharstr() | endwhile
        " some cursor index normalization functions
        let Lower = {idx -> max([0, idx])}
        let Upper = {idx -> min([idx, strcharlen(chars)])}
        let R = {idx -> Lower(Upper(idx))}
        " save some booleans for easier key code determination
        let c_abort = c == "\<ESC>"
        let c_enter = (c == "\<CR>") || (c == "\<NL>")
                    \ || (c == "\<C-M>") || (c == "\<C-J>")
        let c_break = c_abort || c_enter
        let c_up_compl = (c == "\<S-Tab>") || (c == "\<Up>")
        let c_down_compl = (c == "\<Tab>") || (c == "\<Down>")
        let c_compl = c_up_compl || c_down_compl
        if c_break
            " End loop, if the user aborted, set the characters to v:none, otherwise, the
            " user specified to enter the input
            if c_abort | let chars = v:none | endif
            break
        elseif c_compl
            " Handle completion
            if (a:complete isnot v:none) && !empty(a:complete)
                " get current completions if we were not in completion mode
                if complete_stub is v:none
                    let complete_stub = chars
                    try
                        let complete_list = s:getcompletion_custom(
                                    \ complete_stub, a:complete,
                                    \ strcharpart(chars, 0, cursor_idx),
                                    \ chars, byteidx(chars, cursor_idx))
                    catch 'E475'
                        " the function might not cooperate so catch that and just end
                        " the loop instead of trapping the user in an empty screen
                        throw 'VimSE: Invalid completion argument -- '.v:exception
                    endtry
                    " complete_list is of form [stub, ...options] so wrapping is easier
                    call insert(complete_list, complete_stub, 0)
                    let complete_idx  = 0
                endif
                let complete_idx += c_down_compl ? +1 : -1
                " wrap-around
                let complete_idx %= len(complete_list)
                let chars = complete_list[complete_idx]
            endif
        else
            if complete_stub isnot v:none
                " we are in complete mode but it was not tab so use the current prompt
                let complete_stub = v:none
                let complete_list = []
                let complete_idx  = 0
            endif
            " Handle non-complete key sequences
            if c == "\<Left>"
                let cursor_idx = R(cursor_idx - 1)
            elseif c == "\<Right>"
                let cursor_idx = R(cursor_idx + 1)
            elseif (c == "\<C-B>") || (c == "\<Home>")
                let cursor_idx = 0
            elseif (c == "\<C-E>") || (c == "\<End>")
                let cursor_idx = R(strcharlen(chars))
            elseif (c == "\<S-Left>") || (c == "\<C-Left>")
                " puts cursor *at the start of* a word, starting at the cursor backwards
                let cursor_idx = R(vimsetext#RCharMatch(chars, '\>', cursor_idx))
            elseif (c == "\<S-Right>") || (c == "\<C-Right>")
                " puts cursor *after* a word, starting at the cursor
                let cursor_idx = R(vimsetext#CharMatch(chars, '\>', cursor_idx))
            elseif (c == "\<C-H>") || (c == "\<BS>")
                " remove previous character at cursor, and move it back
                let chars = strcharpart(chars, 0, R(cursor_idx - 1))
                            \ ..strcharpart(chars, cursor_idx)
                let cursor_idx = R(cursor_idx - 1)
            elseif c == "\<Del>"
                " remove first character at cursor, and do not move it
                let chars = strcharpart(chars, 0, cursor_idx)
                            \ ..strcharpart(chars, R(cursor_idx + 1))
            elseif c == "\<C-W>"
                " removes the previously-typed word, very similar to <C-Left>
                let word_idx = R(vimsetext#RCharMatch(chars, '\>', cursor_idx))
                let chars = strcharpart(chars, 0, word_idx)
                            \ ..strcharpart(chars, cursor_idx)
                " R(...) already called on 'word_idx'
                let cursor_idx = word_idx
            elseif c == "\<C-U>"
                " removes charactert between cursor and the beginning of the line
                let chars = strcharpart(chars, cursor_idx)
                let cursor_idx = 0
            else
                " append/insert character if any other key is pressed
                let chars = strcharpart(chars, 0, cursor_idx)
                            \ ..c
                            \ ..strcharpart(chars, cursor_idx)
                let cursor_idx = R(cursor_idx + strcharlen(c))
            endif
        endif
        " Notify callback function, and break loop if it exits with a truthy value
        if a:Onchange isnot v:none
            if a:Onchange(chars, c) | break | endif
        endif
        " Print prompt and so far entered characters
        redraw
        echon a:prompt strcharpart(chars, 0, cursor_idx)
        echohl VimSEUnderline | echon strcharpart(chars, cursor_idx, 1) | echohl None
        echon strcharpart(chars, R(cursor_idx + 1))
    endwhile
    if a:OnEnd isnot v:none | call a:OnEnd(chars) | endif

    redraw
    call inputrestore()
    return chars
endfunction


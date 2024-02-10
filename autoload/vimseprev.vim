" Popup and preview utilities for VimSE.
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 20.01.2024
" License: See 'LICENSE' shipped with this repository
" (c) Marcel Simader 2024

augroup VimSECallbacks
    autocmd!
    autocmd WinClosed *
                \ exe 'call <SID>WinKill(expand("<afile>"), winbufnr(expand("<afile>")))'
    autocmd BufWinLeave *
                \ exe 'call <SID>WinKill(bufwinid(expand("<afile>")), bufnr(expand("<afile>")))'
    autocmd ModeChanged [^c]*:[^c]*
                \ exe 'call <SID>WinKill(bufwinid(expand("<afile>")), bufnr(expand("<afile>")))'
    autocmd WinScrolled * exe 'call <SID>WinResize(copy(v:event))'
augroup END

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Private Functions ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function s:PrintPopup(popup)
    echomsg 'Popup '.a:popup['id'].' @'.a:popup['winid'].':'.a:popup['bufnr']
endfunction

function s:WinKill(winid, bufnr)
    " When there are no previews, we can just ignore any event, for speed
    if len(g:VIMSE_open_previews) < 1 | return | endif
    for obj in g:VIMSE_open_previews
        if obj['winid'] != a:winid || obj['bufnr'] != a:bufnr | continue | endif
        call obj['close']()
    endfor
    " This helps, because 1.) we don't have to keep track fo an index or remove while
    " iterating, and 2.) if a popup window disappeared for some other reason, we have to
    " detect that anyway
    const popup_ids = popup_list()
    call filter(g:VIMSE_open_previews, {_, obj -> index(popup_ids, obj['id']) != -1})
endfunction

if has('timers')
    function s:WinResize(event_wins)
        " When there are no previews, we can just ignore any event, for speed
        if len(g:VIMSE_open_previews) < 1 | return | endif
        " Check if the event is really a dictionary
        if type(a:event_wins) isnot v:t_dict | return | endif
        for winid in keys(a:event_wins)
            " See |WinScrolled-event| for 'all' key
            if winid == 'all' | continue | endif
            if has_key(g:VIMSE_resize_timer, winid) | continue | endif
            let g:VIMSE_resize_timer[winid]
                        \ = timer_start(80, {-> s:_WinResize(winid)})
        endfor
    endfunction
else
    function s:WinResize(event_wins)
        if len(g:VIMSE_open_previews) < 1 | return | endif
        if type(a:event_wins) isnot v:t_dict | return | endif
        for winid in keys(a:event_wins) | call s:_WinResize(winid) | endfor
    endfunction
endif

function s:_WinResize(winid)
    for obj in g:VIMSE_open_previews
        " Sticky previews don't get updated, ever
        if get(obj, 'sticky', v:false) | continue | endif
        " Check if the window containing the preview was resized, specifically
        if obj['winid'] != a:winid | continue | endif
        call obj['reposition']()
    endfor
    silent! unlet g:VIMSE_resize_timer[a:winid]
endfunction

" Calculates a popup window's position and size given the window-id and (buffer) line
" number. The resulting dict has the keys 'line', 'col', 'width', and 'hidden'.
function s:CalcPopupSize(winid, lnum, text)
    "                           winwidth
    "               /---------------^---------------\
    "
    "            ---+-------------------------------+---
    " nr_lines /    | 123... | This is buffer text  |    <- screenpos['row']
    "          \    | ...    | ...                  |
    "            ---+-------------------------------+---
    "
    "               ^          ^
    "               |          |
    "               |      screenpos['col']
    "            wincol
    const nr_lines  = count(a:text, "\n")
    const wininfo   = get(getwininfo(a:winid), 0, {})
    const leftcol   = get(wininfo, 'wincol', 1) - get(wininfo, 'textoff', 0)
    const screenpos = screenpos(a:winid, a:lnum, 1)
    const width     = winwidth(a:winid) - (screenpos['col'] - leftcol)
    " this means the popup is not visible
    const hidden    = (screenpos['row'] == 0) && (screenpos['col'] == 0)
    return { 'line': screenpos['row'],
           \ 'col': screenpos['col'],
           \ 'width': width,
           \ 'height': nr_lines,
           \ 'hidden': hidden,
           \ }
endfunction

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Public API ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" Takes in a window, a line number, and a text. It then overlays a borderless popup over
" the given line in the given window. This can be used to preview the contents of a line
" before a change is made, hence the name.
"
" Arguments:
"   winid, the window id to place the popup into
"   lnum, the *buffer* line number
"   [sticky,] when this option is true, the popup will 'stick' to the window, and not the
"       virtual buffer line, false by default
"   [allow_movement,] when this option is false, all movement outside the line will make
"       the popup disappear, changing buffers will always close the popup, false by default
"   [default_text,] the text to display by default, if left blank, this will be the text
"       from the buffer
"   [extra_options,] extra options to pass to the 'popup_create' function
"
" Returns:
"   function references to 'update' (takes 1 text argument), and 'close' (no arguments),
"   and the data values 'id' (popup ID), 'lnum' (in buffer), 'winid', 'bufnr', and 'text'.
"
"   NOTE: The data values should *NOT* be modified directly!
"
function vimseprev#LinePreview(winid, lnum,
            \ sticky = v:false, allow_movement = v:false,
            \ default_text = v:none, extra_options = {})
    const text = (a:default_text is v:none)
                \    ? get(getbufline(winbufnr(a:winid), a:lnum), 0, '')
                \    : a:default_text
    const pos_info = s:CalcPopupSize(a:winid, a:lnum, text)
    const popup_id  = popup_create(
                \ text,
                \ extend(
                \     {
                \         'pos'       : 'topleft',
                \         'line'      : pos_info['line'],
                \         'col'       : pos_info['col'],
                \         'minwidth'  : pos_info['width'],
                \         'maxwidth'  : pos_info['width'],
                \         'hidden'    : pos_info['hidden'],
                \         'minheight' : pos_info['height'],
                \         'maxheight' : pos_info['height'],
                \         'fixed'     : 1,
                \         'wrap'      : 0,
                \         'drag'      : 0,
                \         'resize'    : 0,
                \         'cursorline': 1,
                \         'moved'     : a:allow_movement ? [0, 0, 0] : 'any',
                \         'close'     : 'click',
                \     },
                \     a:extra_options,
                \     'force',
                \ ))
    " important! otherwise this will just not show up
    redraw
    let obj = { 'id': popup_id,
              \ 'lnum': a:lnum,
              \ 'winid': win_getid(),
              \ 'bufnr': bufnr(),
              \ 'text': text,
              \ 'sticky': a:sticky,
              \ }
    " ~~~ Start dict functions
    function obj.update(text)
        let self['text'] = a:text
        call popup_settext(self['id'], a:text)
        call self['reposition']()
    endfunction
    " ~~~
    function obj.reposition()
        let pos_info = s:CalcPopupSize(self['winid'], self['lnum'], self['text'])
        if pos_info['hidden']
            call popup_hide(self['id'])
        else
            call popup_show(self['id'])
            call popup_move(self['id'], { 'line': pos_info['line'],
                                        \ 'col': pos_info['col'],
                                        \ 'minwidth': pos_info['width'],
                                        \ 'maxwidth': pos_info['width'],
                                        \ 'minheight' : pos_info['height'],
                                        \ 'maxheight' : pos_info['height'],
                                        \ })
        endif
        redraw
    endfunction
    " ~~~
    function obj.close()
        call popup_close(self['id'])
        const idx = indexof(g:VIMSE_open_previews, {_, v -> v['id'] == self['id']})
        if idx < 0 | return | endif
        " it might be that we have some race condition that closes it while we run this
        " function, so better silence it.
        silent! call remove(g:VIMSE_open_previews, idx)
    endfunction
    " ~~~ End dict functions
    let g:VIMSE_open_previews += [obj]
    return obj
endfunction

" Closes all popups.
function vimseprev#CloseAllPreviews()
    for obj in g:VIMSE_open_previews | call obj['close']() | endfor
    call assert_true(len(g:VIMSE_open_previews) < 1)
endfunction

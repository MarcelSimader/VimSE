" Main file of VimSE, a general purpose 'runtime library' for Vim.
" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 15.12.2021
" License: See 'LICENSE' shipped with this repository
" (c) Marcel Simader 2021

" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~ Global Fields ~~~~~~~~~~~~~~~~~~~~
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" Conservative estimate about how long a line can be for these functions to work, unless
" maxcol is available, which it should almost always be.
let g:VIMSE_EOL = exists('v:maxcol') ? v:maxcol : 99999

" Keeps track of previews, so that we always have a way to close them all.
let g:VIMSE_open_previews = []

" The current resize timer for a preview, as dictionary with keys for preview IDs, and
" values for the timer |Funcref|.
let g:VIMSE_resize_timer = {}

" A highlighting group that simply uses an underline. Used, for instance, for the fake
" cursor in the asynchronous input function.
highlight VimSEUnderline term=underline cterm=underline gui=underline

" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 10.02.2024
" (c) Marcel Simader 2024

" Force reloading of functions in autoload script
execute 'source '.g:TEST_DIR.'/../autoload/vimsetemplate.vim'

let s:TestTStr = function('TestBuffer', ['vimsetemplate#TemplateString', v:none])
let s:TestTInl = function('TestBuffer', ['vimsetemplate#InlineTemplate', v:none])
let s:TestTmpl = function('TestBuffer', ['vimsetemplate#Template', v:none])

" ~~~~~~~~~~~~~~~~~~~~ Tests ~~~~~~~~~~~~~~~~~~~~

" Empty inputs
function! test_template#t0()
    call s:TestTStr([], [], win_getid(), 1, 1, 0, g:VIMSE_EOL, 0)
    call s:TestTStr(['Some text'], ['Some text'], win_getid(), 0, 0, 1, g:VIMSE_EOL, 0)
    call s:TestTStr(['Some text'], ['Some text'], win_getid(), 1, 1, 1, 1, 0)
endfunction

" TODO(Marcel): More tests, please :<

" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 06.02.2023
" (c) Marcel Simader 2023

" Force reloading of functions in autoload script
execute 'source '.g:TEST_DIR.'/../autoload/vimse.vim'

function! s:Test(expected_buffer, buffer, lnum, lines, indent)
    return function('TestBuffer', ['vimse#SmartInsert', v:none])(
                \ a:expected_buffer, a:buffer, a:lnum, a:lines, a:indent)
endfunction

" ~~~~~~~~~~~~~~~~~~~~ Pre ~~~~~~~~~~~~~~~~~~~~

function! test_smartinsert#before()
    " Force a certain shift-width
    setlocal shiftwidth=4
endfunction

function! test_smartinsert#after()
    set shiftwidth<
endfunction

" ~~~~~~~~~~~~~~~~~~~~ Tests ~~~~~~~~~~~~~~~~~~~~

" Empty examples
function! test_smartinsert#t0()
    call s:Test([''], [], 1, [], -1)
    call s:Test([''], [''], 1, [''], -1)
    call s:Test([''], [''], 4, [''], 31)
endfunction

" Simple examples
function! test_smartinsert#t1()
    call s:Test(['Hi'],
                \ ['Test'], 1, ['Hi'], -1)
    call s:Test(['Hi', '  Hoy'],
                \ ['Test', '  Hoy'], 1, ['Hi'], -1)
    call s:Test(['Test', 'Hi'],
                \ ['Test', '  Hoy'], 2, ['Hi'], -1)
endfunction

" Indent examples
function! test_smartinsert#t2()
    call s:Test(['  Hi'],
                \ ['Test'], 1, ['Hi'], 2)
    call s:Test(['    Hi', '  Hoy'],
                \ ['Test', '  Hoy'], 1, ['Hi'], 4)
    call s:Test(['Test', '   Hi'],
                \ ['Test', '  Hoy'], 2, ['Hi'], 3)
endfunction

" Multiline indent examples
function! test_smartinsert#t3()
    call s:Test(['Test', '  This', '    is a test', 'Line 2', '  Line 3!'],
                \ ['Test', '', 'Line 2', '  Line 3!'], 2, ['This', '  is a test'], 2)
    call s:Test(['Test', '', 'This', '  is a test', '  Line 3!'],
                \ ['Test', '', 'Line 2', '  Line 3!'], 3, ['This', '  is a test'], 0)
endfunction

" Real-life examples
function! test_smartinsert#t4()
    call s:Test(['class A:', '  some_field: str', '  ', '  def test(self) -> None:', '    print("hi")'],
                \ ['class A:', '', '  def test(self) -> None:', '    print("hi")'],
                \ 2, ['some_field: str', ''], 2)
endfunction


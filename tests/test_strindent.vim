" Author: Marcel Simader (marcel0simader@gmail.com)
" Date: 05.02.2023
" (c) Marcel Simader 2023

" Force reloading of functions in autoload script
execute 'source '.g:TEST_DIR.'/../autoload/vimsetext.vim'

function! s:Test(str, expected_indent)
    call assert_equal(a:expected_indent, vimsetext#StrIndent(a:str))
endfunction

" ~~~~~~~~~~~~~~~~~~~~ Tests ~~~~~~~~~~~~~~~~~~~~

" Simple inputs
function! test_strindent#t0()
    call s:Test("", 0)
    call s:Test(" ", 1)
    call s:Test("  ", 2)
    call s:Test("  abc", 2)
    call s:Test("  This\nis a test", 2)
    call s:Test("Another test\n    Yup", 0)
endfunction

" Tab characters, shiftwidth
function! test_strindent#t1()
    let sw = shiftwidth()
    call s:Test("\t", sw)
    call s:Test(" \t  abc", sw + 3)
    call s:Test(" \t\t\t    abc\t\n  \t", (3 * sw) + 5)
endfunction

" Multi-byte characters
function! test_strindent#t2()
    call s:Test("ö", 0)
    call s:Test(" ö ", 1)
endfunction

